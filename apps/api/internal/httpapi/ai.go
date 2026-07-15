package httpapi

import (
	"bufio"
	"bytes"
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

type providerSecret struct {
	publicProvider
	APIKeyCiphertext []byte
	APIKeyNonce      []byte
}

func (s *Server) handleAdminAITest(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "admin_ai_test", identity.ID, 10); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "测试过于频繁，请稍后重试")
		return
	}
	var input struct {
		ProviderID string `json:"providerId"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	provider, key, err := s.loadProvider(r.Context(), input.ProviderID, identity.ID, false)
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "AI 服务不存在")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 25*time.Second)
	defer cancel()
	result, err := s.postProviderJSON(ctx, provider, key, "/responses", map[string]any{
		"model": provider.TextModel,
		"input": []any{map[string]any{"role": "user", "content": []any{
			map[string]any{"type": "input_text", "text": "Reply exactly: DAYLINK_OK"},
		}}},
		"store": false,
	}, 2<<20)
	if err == nil {
		responseID, _ := result["id"].(string)
		_, hasOutput := result["output"].([]any)
		if responseID == "" || !hasOutput {
			err = errors.New("provider returned an invalid Responses payload")
		}
	}
	if err != nil {
		s.audit(r.Context(), identity.Actor, "ai_provider.test", "ai_provider", provider.ID, "failed", "low")
		writeError(w, http.StatusBadGateway, "provider_test_failed", "AI 服务连接失败，请检查 API 地址、模型和 API Key")
		return
	}
	s.audit(r.Context(), identity.Actor, "ai_provider.test", "ai_provider", provider.ID, "allowed", "low")
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (s *Server) handleAssistantResponses(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "assistant_responses", identity.AccountID, 120); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "AI 请求过于频繁，请稍后重试")
		return
	}
	var input struct {
		ProviderID         string            `json:"providerId"`
		Input              json.RawMessage   `json:"input"`
		Tools              []json.RawMessage `json:"tools"`
		PreviousResponseID string            `json:"previous_response_id,omitempty"`
		Store              *bool             `json:"store,omitempty"`
		ParallelToolCalls  *bool             `json:"parallel_tool_calls,omitempty"`
	}
	if err := decodeJSON(r, &input); err != nil || input.ProviderID == "" || len(input.Input) == 0 || len(input.Tools) > 64 ||
		(input.ParallelToolCalls != nil && *input.ParallelToolCalls) {
		writeError(w, http.StatusBadRequest, "invalid_request", "Responses 请求无效")
		return
	}
	tools := make([]any, 0, len(input.Tools))
	for _, raw := range input.Tools {
		var tool map[string]any
		if json.Unmarshal(raw, &tool) != nil || !strictFunctionTool(tool) {
			writeError(w, http.StatusBadRequest, "invalid_tool_schema", "工具必须使用严格 function schema")
			return
		}
		tools = append(tools, tool)
	}
	provider, key, err := s.loadDefaultProviderForApp(r.Context(), input.ProviderID)
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "AI 服务不可用")
		return
	}
	var parsedInput any
	if json.Unmarshal(input.Input, &parsedInput) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "input 无效")
		return
	}
	reservation, err := s.reserveAIUsage(r.Context(), identity.AccountID, "local_ai", "responses", 1)
	if err != nil {
		if !writeAIEntitlementError(w, err) {
			writeError(w, http.StatusServiceUnavailable, "billing_unavailable", "AI 计费服务暂时不可用")
		}
		return
	}
	charged := false
	defer func() {
		s.finishAIUsage(context.WithoutCancel(r.Context()), reservation, charged)
	}()
	body := map[string]any{
		"model": provider.TextModel, "input": parsedInput, "tools": tools,
		"store": true, "parallel_tool_calls": false,
	}
	if input.PreviousResponseID != "" && len(input.PreviousResponseID) <= 200 {
		body["previous_response_id"] = input.PreviousResponseID
	}
	runID := s.startAIRun(r.Context(), identity.AccountID, provider.ID, "assistant", provider.TextModel,
		security.PrivateHash(s.cfg.AIMasterKey, "ai-request", string(input.Input)))
	result, err := s.postProviderJSON(r.Context(), provider, key, "/responses", body, 32<<20)
	if err != nil {
		s.finishAIRun(r.Context(), runID, "failed", "gateway_error", "AI provider request failed", "")
		s.audit(r.Context(), "app:"+identity.AccountID, "ai_gateway.response", "ai_provider", provider.ID, "failed", "medium")
		writeError(w, http.StatusBadGateway, "provider_error", "AI 服务请求失败")
		return
	}
	responseID, _ := result["id"].(string)
	charged = true
	s.finishAIRun(r.Context(), runID, "succeeded", "", "", responseID)
	s.audit(r.Context(), "app:"+identity.AccountID, "ai_gateway.response", "ai_provider", provider.ID, "allowed", "medium")
	writeJSON(w, http.StatusOK, result)
}

func (s *Server) handleAssistantImages(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "assistant_images", identity.AccountID, 30); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "生图请求过于频繁，请稍后重试")
		return
	}
	var input imageRequest
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	provider, key, err := s.loadDefaultProviderForApp(r.Context(), input.ProviderID)
	if err != nil || provider.ImageModel == nil {
		writeError(w, http.StatusNotFound, "image_provider_unavailable", "生图服务不可用")
		return
	}
	reservation, err := s.reserveAIUsage(r.Context(), identity.AccountID, "local_ai", "image", 5)
	if err != nil {
		if !writeAIEntitlementError(w, err) {
			writeError(w, http.StatusServiceUnavailable, "billing_unavailable", "AI 计费服务暂时不可用")
		}
		return
	}
	charged := false
	defer func() {
		s.finishAIUsage(context.WithoutCancel(r.Context()), reservation, charged)
	}()
	image, revised, err := s.generateImage(r.Context(), provider, key, input)
	if err != nil {
		s.audit(r.Context(), "app:"+identity.AccountID, "ai_gateway.image", "ai_provider", provider.ID, "failed", "medium")
		writeError(w, http.StatusBadGateway, "provider_error", "生图服务请求失败")
		return
	}
	charged = true
	s.audit(r.Context(), "app:"+identity.AccountID, "ai_gateway.image", "ai_provider", provider.ID, "allowed", "medium")
	writeJSON(w, http.StatusOK, map[string]any{"created": time.Now().Unix(), "data": []map[string]any{{"b64_json": base64.StdEncoding.EncodeToString(image), "revised_prompt": revised}}})
}

type imageRequest struct {
	ProviderID string `json:"providerId"`
	Prompt     string `json:"prompt"`
	N          int    `json:"n,omitempty"`
	Size       string `json:"size,omitempty"`
	Quality    string `json:"quality,omitempty"`
	Format     string `json:"output_format,omitempty"`
}

func (s *Server) generateAdminImage(w http.ResponseWriter, r *http.Request, identity *adminIdentity) {
	var input imageRequest
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	provider, key, err := s.loadProvider(r.Context(), input.ProviderID, identity.ID, false)
	if err != nil || provider.ImageModel == nil {
		writeError(w, http.StatusBadRequest, "image_provider_unavailable", "该服务未配置生图模型")
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "admin_images", identity.ID, 30); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "生图请求过于频繁，请稍后重试")
		return
	}
	runID := s.startAIRun(r.Context(), identity.ID, provider.ID, "image", *provider.ImageModel,
		security.PrivateHash(s.cfg.AIMasterKey, "ai-request", input.Prompt))
	image, revised, err := s.generateImage(r.Context(), provider, key, input)
	if err != nil {
		s.finishAIRun(r.Context(), runID, "failed", "image_generation_failed", "Image provider request failed", "")
		writeError(w, http.StatusBadGateway, "image_generation_failed", "生图失败，请检查服务配置")
		return
	}
	assetID, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "asset_storage_failed", "图片存储失败")
		return
	}
	path, err := s.writeAsset(assetID, image)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "asset_storage_failed", "图片存储失败")
		return
	}
	width, height := imageDimensions(input.Size)
	_, err = s.db.ExecContext(r.Context(), `INSERT INTO generated_assets
      (id, admin_id, provider_config_id, ai_run_id, object_key, prompt_digest, content_type,
       byte_size, width, height) VALUES (?, ?, ?, ?, ?, ?, 'image/png', ?, ?, ?)`,
		assetID, identity.ID, provider.ID, runID, path,
		security.PrivateHash(s.cfg.AIMasterKey, "ai-request", input.Prompt), len(image), width, height)
	if err != nil {
		_ = os.Remove(filepath.Join(s.cfg.AssetDirectory, path))
		writeError(w, http.StatusInternalServerError, "asset_storage_failed", "图片存储失败")
		return
	}
	s.finishAIRun(r.Context(), runID, "succeeded", "", "", "")
	s.audit(r.Context(), identity.Actor, "image.generate", "generated_asset", assetID, "allowed", "medium")
	writeJSON(w, http.StatusCreated, map[string]any{"asset": map[string]any{
		"id": assetID, "url": "/api/admin/images/" + assetID, "contentType": "image/png", "byteSize": len(image), "revisedPrompt": revised,
	}})
}

func (s *Server) generateImage(ctx context.Context, provider providerSecret, key string, input imageRequest) ([]byte, any, error) {
	input.Prompt = strings.TrimSpace(input.Prompt)
	if len(input.Prompt) == 0 || len(input.Prompt) > 8000 {
		return nil, nil, errors.New("invalid prompt")
	}
	if input.Size == "" {
		input.Size = "1024x1024"
	}
	if input.Quality == "" {
		input.Quality = "medium"
	}
	if input.N == 0 {
		input.N = 1
	}
	if input.Format == "" {
		input.Format = "png"
	}
	validSize := input.Size == "1024x1024" || input.Size == "1536x1024" || input.Size == "1024x1536"
	validQuality := input.Quality == "low" || input.Quality == "medium" || input.Quality == "high"
	if !validSize || !validQuality || input.N != 1 || input.Format != "png" {
		return nil, nil, errors.New("invalid image options")
	}
	result, err := s.postProviderJSON(ctx, provider, key, "/images/generations", map[string]any{
		"model": *provider.ImageModel, "prompt": input.Prompt, "n": 1, "size": input.Size,
		"quality": input.Quality, "output_format": "png",
	}, 40<<20)
	if err != nil {
		return nil, nil, err
	}
	data, ok := result["data"].([]any)
	if !ok || len(data) != 1 {
		return nil, nil, errors.New("provider returned no image")
	}
	first, ok := data[0].(map[string]any)
	if !ok {
		return nil, nil, errors.New("provider returned invalid image")
	}
	b64, _ := first["b64_json"].(string)
	image, err := parseImageData(b64)
	if err != nil {
		remoteURL, _ := first["url"].(string)
		image, err = s.downloadGeneratedImage(ctx, remoteURL)
	}
	return image, first["revised_prompt"], err
}

func (s *Server) downloadGeneratedImage(ctx context.Context, rawURL string) ([]byte, error) {
	parsed, err := url.Parse(rawURL)
	if err != nil || parsed.Scheme != "https" || parsed.Hostname() == "" || parsed.User != nil {
		return nil, errors.New("provider returned invalid image URL")
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, parsed.String(), nil)
	if err != nil {
		return nil, errors.New("provider returned invalid image URL")
	}
	request.Header.Set("Accept", "image/png")
	response, err := s.client.Do(request)
	if err != nil {
		return nil, errors.New("generated image is unreachable")
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 64<<10))
		return nil, errors.New("generated image download failed")
	}
	content, err := io.ReadAll(io.LimitReader(response.Body, (32<<20)+1))
	if err != nil || len(content) > 32<<20 {
		return nil, errors.New("generated image is too large")
	}
	return validatePNGImage(content)
}

func (s *Server) loadProvider(ctx context.Context, providerID, adminID string, enabledOnly bool) (providerSecret, string, error) {
	query := `SELECT id, name, kind, base_url, text_model, image_model, api_key_hint, enabled,
      updated_at, api_key_ciphertext, api_key_nonce FROM ai_provider_configs WHERE id = ?`
	args := []any{providerID}
	if adminID != "" {
		query += " AND admin_id = ?"
		args = append(args, adminID)
	}
	if enabledOnly {
		query += " AND enabled = TRUE"
	}
	var provider providerSecret
	var image sql.NullString
	err := s.db.QueryRowContext(ctx, query, args...).Scan(&provider.ID, &provider.Name, &provider.Kind,
		&provider.BaseURL, &provider.TextModel, &image, &provider.APIKeyHint, &provider.Enabled,
		&provider.UpdatedAt, &provider.APIKeyCiphertext, &provider.APIKeyNonce)
	if err != nil {
		return providerSecret{}, "", err
	}
	if image.Valid {
		provider.ImageModel = &image.String
	}
	plaintext, err := security.Decrypt(s.cfg.AIMasterKey, "provider:"+provider.ID, provider.APIKeyCiphertext, provider.APIKeyNonce)
	if err != nil {
		return providerSecret{}, "", err
	}
	return provider, string(plaintext), nil
}

func (s *Server) postProviderJSON(ctx context.Context, provider providerSecret, apiKey, path string, body any, maximum int64) (map[string]any, error) {
	encoded, err := json.Marshal(body)
	if err != nil {
		return nil, err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, strings.TrimRight(provider.BaseURL, "/")+path, bytes.NewReader(encoded))
	if err != nil {
		return nil, err
	}
	request.Header.Set("Authorization", "Bearer "+apiKey)
	request.Header.Set("Content-Type", "application/json")
	response, err := s.client.Do(request)
	if err != nil {
		return nil, errors.New("provider unreachable")
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 64<<10))
		return nil, fmt.Errorf("provider returned status %d", response.StatusCode)
	}
	if strings.HasPrefix(strings.ToLower(response.Header.Get("Content-Type")), "text/event-stream") {
		return decodeProviderSSE(response.Body, maximum)
	}
	decoder := json.NewDecoder(io.LimitReader(response.Body, maximum))
	var result map[string]any
	if err := decoder.Decode(&result); err != nil {
		return nil, errors.New("provider returned invalid JSON")
	}
	return result, nil
}

func decodeProviderSSE(reader io.Reader, maximum int64) (map[string]any, error) {
	if maximum < 1 {
		return nil, errors.New("provider response limit is invalid")
	}
	scanner := bufio.NewScanner(io.LimitReader(reader, maximum+1))
	maximumToken := int(min(maximum, 8<<20))
	scanner.Buffer(make([]byte, 64<<10), maximumToken)
	var eventName string
	var data strings.Builder
	var lastResponse map[string]any
	consumed := int64(0)
	flush := func() (map[string]any, error) {
		defer func() {
			eventName = ""
			data.Reset()
		}()
		raw := strings.TrimSpace(data.String())
		if raw == "" || raw == "[DONE]" {
			return nil, nil
		}
		var event map[string]any
		if json.Unmarshal([]byte(raw), &event) != nil {
			return nil, errors.New("provider returned invalid SSE data")
		}
		eventType, _ := event["type"].(string)
		if eventType == "error" || eventType == "response.failed" || eventName == "error" || eventName == "response.failed" {
			return nil, errors.New("provider returned a failed Responses event")
		}
		if response, ok := event["response"].(map[string]any); ok {
			lastResponse = response
			if eventType == "response.completed" || eventName == "response.completed" {
				return response, nil
			}
		}
		if _, hasID := event["id"].(string); hasID {
			if _, hasOutput := event["output"].([]any); hasOutput {
				lastResponse = event
			}
		}
		return nil, nil
	}
	for scanner.Scan() {
		line := scanner.Text()
		consumed += int64(len(line) + 1)
		if consumed > maximum {
			return nil, errors.New("provider response exceeded limit")
		}
		if line == "" || line == "\r" {
			result, err := flush()
			if err != nil || result != nil {
				return result, err
			}
			continue
		}
		line = strings.TrimSuffix(line, "\r")
		switch {
		case strings.HasPrefix(line, "event:"):
			eventName = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
		case strings.HasPrefix(line, "data:"):
			if data.Len() > 0 {
				data.WriteByte('\n')
			}
			data.WriteString(strings.TrimSpace(strings.TrimPrefix(line, "data:")))
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, errors.New("provider returned invalid SSE stream")
	}
	if data.Len() > 0 {
		result, err := flush()
		if err != nil || result != nil {
			return result, err
		}
	}
	if lastResponse != nil {
		return lastResponse, nil
	}
	return nil, errors.New("provider SSE stream ended without a response")
}

func strictFunctionTool(tool map[string]any) bool {
	if tool["type"] != "function" || tool["strict"] != true {
		return false
	}
	name, ok := tool["name"].(string)
	if !ok || !toolNamePattern.MatchString(name) {
		return false
	}
	parameters, ok := tool["parameters"].(map[string]any)
	if !ok || !strictJSONSchema(parameters, 0) {
		return false
	}
	return true
}

var toolNamePattern = regexp.MustCompile(`^[A-Za-z0-9_-]{1,64}$`)

func strictJSONSchema(schema map[string]any, depth int) bool {
	if depth > 16 {
		return false
	}
	typeName, ok := schema["type"].(string)
	if !ok {
		return false
	}
	switch typeName {
	case "object":
		if schema["additionalProperties"] != false {
			return false
		}
		properties, ok := schema["properties"].(map[string]any)
		if !ok {
			return false
		}
		for name, raw := range properties {
			if name == "" {
				return false
			}
			child, ok := raw.(map[string]any)
			if !ok || !strictJSONSchema(child, depth+1) {
				return false
			}
		}
		if required, exists := schema["required"]; exists {
			items, ok := required.([]any)
			if !ok {
				return false
			}
			seen := make(map[string]bool, len(items))
			for _, item := range items {
				name, ok := item.(string)
				if !ok || seen[name] || properties[name] == nil {
					return false
				}
				seen[name] = true
			}
		}
		return true
	case "array":
		items, ok := schema["items"].(map[string]any)
		return ok && strictJSONSchema(items, depth+1)
	case "string", "integer", "number", "boolean", "null":
		return true
	default:
		return false
	}
}

func (s *Server) startAIRun(ctx context.Context, actorID, providerID, kind, model, digest string) string {
	id, err := security.RandomID()
	if err != nil {
		return ""
	}
	_, _ = s.db.ExecContext(ctx, `INSERT INTO ai_runs
      (id, actor_id, provider_config_id, kind, status, model, request_digest, started_at)
      VALUES (?, ?, ?, ?, 'running', ?, ?, UTC_TIMESTAMP(6))`, id, actorID, providerID, kind, model, digest)
	return id
}

func (s *Server) finishAIRun(ctx context.Context, id, status, code, message, responseID string) {
	if id == "" {
		return
	}
	_, _ = s.db.ExecContext(ctx, `UPDATE ai_runs SET status = ?, error_code = NULLIF(?, ''),
      error_message = NULLIF(?, ''), response_id = NULLIF(?, ''), completed_at = UTC_TIMESTAMP(6)
      WHERE id = ?`, status, code, message, responseID, id)
}

func imageDimensions(size string) (any, any) {
	if size == "" {
		size = "1024x1024"
	}
	parts := strings.Split(size, "x")
	if len(parts) != 2 {
		return nil, nil
	}
	width, widthErr := strconv.Atoi(parts[0])
	height, heightErr := strconv.Atoi(parts[1])
	if widthErr != nil || heightErr != nil {
		return nil, nil
	}
	return width, height
}
