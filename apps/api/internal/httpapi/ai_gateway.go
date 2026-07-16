package httpapi

import (
	"bufio"
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

const (
	aiGatewayTokenTTL    = 12 * time.Hour
	maximumGatewayBody   = 8 << 20
	maximumGatewayOutput = 64 << 20
)

type aiGatewayIdentity struct {
	AccountID string
	TokenID   string
}

func (s *Server) handleAppAIRemoteToken(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "ai_remote_token", identity.AccountID, 20); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "远程 Agent 凭证申请过于频繁")
		return
	}
	entitlement, err := s.loadAIEntitlement(r.Context(), identity.AccountID, time.Now().UTC())
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "billing_unavailable", "AI 计费服务暂时不可用")
		return
	}
	if !entitlement.Active || entitlement.ExpiresAt == nil {
		writeError(w, http.StatusPaymentRequired, "subscription_required", "AI 套餐未开通或已到期")
		return
	}
	provider, _, err := s.loadDefaultAIProvider(r.Context())
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "ai_unavailable", "AI 服务尚未配置")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "ai_unavailable", "AI 服务暂时不可用")
		return
	}
	preference, err := s.resolveAISelection(r.Context(), identity.AccountID, provider, "", "")
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "ai_unavailable", "AI 模型目录暂时不可用")
		return
	}
	now := time.Now().UTC()
	expiresAt := now.Add(aiGatewayTokenTTL)
	if entitlement.ExpiresAt.Before(expiresAt) {
		expiresAt = *entitlement.ExpiresAt
	}
	token, err := security.RandomToken("dlkc_")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token_create_failed", "暂时无法创建远程 Agent 凭证")
		return
	}
	tokenID, err := security.RandomID()
	if err == nil {
		_, err = s.db.ExecContext(r.Context(), `INSERT INTO ai_gateway_tokens
      (id, account_id, app_session_id, token_hash, expires_at) VALUES (?, ?, ?, ?, ?)`,
			tokenID, identity.AccountID, identity.SessionID, security.SHA256(token), expiresAt)
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "token_create_failed", "暂时无法创建远程 Agent 凭证")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "ai_gateway_token.create", "ai_gateway_token", tokenID, "allowed", "high")
	writeJSON(w, http.StatusCreated, map[string]any{
		"gateway": map[string]any{
			"baseUrl": strings.TrimRight(s.cfg.PublicOrigin, "/") + "/v1",
			"token":   token, "model": preference.TextModel,
			"reasoningEffort": preference.ReasoningEffort, "expiresAt": expiresAt,
		},
	})
}

func (s *Server) handleAIGatewayModels(w http.ResponseWriter, r *http.Request) {
	if _, ok := s.requireAIGateway(w, r); !ok {
		return
	}
	provider, _, err := s.loadDefaultAIProvider(r.Context())
	if err != nil {
		writeGatewayError(w, http.StatusServiceUnavailable, "ai_unavailable", "AI 服务暂时不可用")
		return
	}
	catalog, err := s.listProviderModels(r.Context(), provider.ID, true)
	if err != nil {
		writeGatewayError(w, http.StatusServiceUnavailable, "ai_unavailable", "AI 模型目录暂时不可用")
		return
	}
	models := make([]map[string]any, 0, len(catalog))
	for _, model := range catalog {
		models = append(models, map[string]any{"id": model.ID, "object": "model", "owned_by": "daylink", "kind": model.Kind})
	}
	writeJSON(w, http.StatusOK, map[string]any{"object": "list", "data": models})
}

func (s *Server) handleAIGatewayResponses(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAIGateway(w, r)
	if !ok {
		return
	}
	s.proxyAIGatewayRequest(w, r, identity, "responses", "/responses", false)
}

func (s *Server) handleAIGatewayImages(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAIGateway(w, r)
	if !ok {
		return
	}
	s.proxyAIGatewayRequest(w, r, identity, "image", "/images/generations", true)
}

func (s *Server) proxyAIGatewayRequest(w http.ResponseWriter, r *http.Request, identity *aiGatewayIdentity, kind, upstreamPath string, image bool) {
	if retry, err := s.consumeRateLimit(r.Context(), r, "ai_gateway_"+kind, identity.AccountID, 180); err != nil {
		writeGatewayError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeGatewayError(w, http.StatusTooManyRequests, "rate_limited", "AI 请求过于频繁")
		return
	}
	raw, err := io.ReadAll(io.LimitReader(r.Body, maximumGatewayBody+1))
	if err != nil || len(raw) == 0 || len(raw) > maximumGatewayBody {
		writeGatewayError(w, http.StatusRequestEntityTooLarge, "invalid_request", "请求内容过大或无效")
		return
	}
	var body map[string]any
	if json.Unmarshal(raw, &body) != nil || body == nil {
		writeGatewayError(w, http.StatusBadRequest, "invalid_request", "请求 JSON 无效")
		return
	}
	provider, key, err := s.loadDefaultAIProvider(r.Context())
	if err != nil || (image && provider.ImageModel == nil) {
		writeGatewayError(w, http.StatusServiceUnavailable, "ai_unavailable", "AI 服务暂时不可用")
		return
	}
	selectedModel := ""
	if image {
		selectedModel, _ = body["model"].(string)
		if selectedModel == "" {
			selectedModel = *provider.ImageModel
		}
		enabled, checkErr := s.modelIsEnabled(r.Context(), provider.ID, selectedModel, "image")
		if checkErr != nil {
			writeGatewayError(w, http.StatusServiceUnavailable, "ai_unavailable", "AI 模型目录暂时不可用")
			return
		}
		if !enabled {
			writeGatewayError(w, http.StatusBadRequest, "model_not_found", "所选生图模型不可用")
			return
		}
		body["model"] = selectedModel
	} else {
		requestedModel, _ := body["model"].(string)
		requestedEffort, valid := reasoningEffortFromBody(body)
		if !valid {
			writeGatewayError(w, http.StatusBadRequest, "invalid_reasoning_effort", "推理强度仅支持 low、medium、high、xhigh")
			return
		}
		preference, selectionErr := s.resolveAISelection(r.Context(), identity.AccountID, provider, requestedModel, requestedEffort)
		if selectionErr != nil {
			writeGatewayError(w, http.StatusBadRequest, "model_not_found", "所选模型或推理强度不可用")
			return
		}
		selectedModel = preference.TextModel
		body["model"] = selectedModel
		reasoning, _ := body["reasoning"].(map[string]any)
		if reasoning == nil {
			reasoning = make(map[string]any)
		}
		reasoning["effort"] = preference.ReasoningEffort
		body["reasoning"] = reasoning
		body["store"] = false
	}
	encoded, err := json.Marshal(body)
	if err != nil {
		writeGatewayError(w, http.StatusBadRequest, "invalid_request", "请求 JSON 无效")
		return
	}
	reservedTokens := estimateImageReservation()
	if !image {
		reservedTokens = estimateResponseReservation(len(encoded), body)
	}
	reservation, err := s.reserveAIUsage(r.Context(), identity.AccountID, "ssh_agent", kind, selectedModel, reservedTokens)
	if err != nil {
		if !writeAIGatewayEntitlementError(w, err) {
			writeGatewayError(w, http.StatusServiceUnavailable, "billing_unavailable", "AI 计费服务暂时不可用")
		}
		return
	}
	var actualUsage *providerTokenUsage
	defer func() {
		s.finishAIUsage(context.WithoutCancel(r.Context()), reservation, actualUsage)
	}()
	request, err := http.NewRequestWithContext(r.Context(), http.MethodPost,
		strings.TrimRight(provider.BaseURL, "/")+upstreamPath, bytes.NewReader(encoded))
	if err != nil {
		writeGatewayError(w, http.StatusBadGateway, "provider_error", "AI 服务请求失败")
		return
	}
	request.Header.Set("Authorization", "Bearer "+key)
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", r.Header.Get("Accept"))
	response, err := s.client.Do(request)
	if err != nil {
		s.audit(r.Context(), "app:"+identity.AccountID, "ai_gateway.remote."+kind, "ai_provider", provider.ID, "failed", "medium")
		writeGatewayError(w, http.StatusBadGateway, "provider_error", "AI 服务请求失败")
		return
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 64<<10))
		s.audit(r.Context(), "app:"+identity.AccountID, "ai_gateway.remote."+kind, "ai_provider", provider.ID, "failed", "medium")
		writeGatewayError(w, http.StatusBadGateway, "provider_error", "AI 服务请求失败")
		return
	}
	contentType := response.Header.Get("Content-Type")
	if contentType == "" {
		contentType = "application/json"
	}
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(http.StatusOK)
	writer := io.Writer(w)
	if flusher, ok := w.(http.Flusher); ok && strings.HasPrefix(strings.ToLower(contentType), "text/event-stream") {
		writer = &flushingWriter{writer: w, flusher: flusher}
	}
	usage, copyErr := copyProviderResponse(writer, response.Body, contentType, maximumGatewayOutput)
	if copyErr == nil {
		actualUsage = usage
		s.audit(context.WithoutCancel(r.Context()), "app:"+identity.AccountID, "ai_gateway.remote."+kind, "ai_provider", provider.ID, "allowed", "medium")
	}
}

func reasoningEffortFromBody(body map[string]any) (string, bool) {
	reasoning, ok := body["reasoning"].(map[string]any)
	if !ok {
		return "", body["reasoning"] == nil
	}
	effort, _ := reasoning["effort"].(string)
	return effort, effort == "" || validAIReasoningEffort(effort)
}

func copyProviderResponse(writer io.Writer, reader io.Reader, contentType string, maximum int64) (*providerTokenUsage, error) {
	if !strings.HasPrefix(strings.ToLower(contentType), "text/event-stream") {
		content, err := io.ReadAll(io.LimitReader(reader, maximum+1))
		if err != nil || int64(len(content)) > maximum {
			return nil, errors.New("provider response exceeded limit")
		}
		if _, err := writer.Write(content); err != nil {
			return nil, err
		}
		payload, err := decodeProviderEvent(content)
		if err != nil {
			return nil, nil
		}
		if usage, ok := extractProviderTokenUsage(payload); ok {
			return &usage, nil
		}
		return nil, nil
	}
	buffered := bufio.NewReader(io.LimitReader(reader, maximum+1))
	consumed := int64(0)
	var latest *providerTokenUsage
	for {
		line, err := buffered.ReadBytes('\n')
		consumed += int64(len(line))
		if consumed > maximum {
			return nil, errors.New("provider response exceeded limit")
		}
		if len(line) > 0 {
			if _, writeErr := writer.Write(line); writeErr != nil {
				return nil, writeErr
			}
			trimmed := bytes.TrimSpace(line)
			if bytes.HasPrefix(trimmed, []byte("data:")) {
				data := bytes.TrimSpace(bytes.TrimPrefix(trimmed, []byte("data:")))
				if len(data) > 0 && !bytes.Equal(data, []byte("[DONE]")) {
					if payload, decodeErr := decodeProviderEvent(data); decodeErr == nil {
						if usage, ok := extractProviderTokenUsage(payload); ok {
							captured := usage
							latest = &captured
						}
					}
				}
			}
		}
		if errors.Is(err, io.EOF) {
			return latest, nil
		}
		if err != nil {
			return nil, err
		}
	}
}

func (s *Server) requireAIGateway(w http.ResponseWriter, r *http.Request) (*aiGatewayIdentity, bool) {
	authorization := r.Header.Get("Authorization")
	if !strings.HasPrefix(authorization, "Bearer dlkc_") || len(authorization) > 300 {
		writeGatewayError(w, http.StatusUnauthorized, "unauthorized", "远程 Agent 凭证无效")
		return nil, false
	}
	var identity aiGatewayIdentity
	err := s.db.QueryRowContext(r.Context(), `SELECT t.account_id, t.id FROM ai_gateway_tokens t
      JOIN app_accounts a ON a.id = t.account_id
      JOIN app_ai_subscriptions sub ON sub.account_id = t.account_id
      JOIN app_sessions s ON s.id = t.app_session_id AND s.account_id = t.account_id
      WHERE t.token_hash = ? AND t.revoked_at IS NULL AND t.expires_at > UTC_TIMESTAMP(6)
        AND s.revoked_at IS NULL AND s.refresh_expires_at > UTC_TIMESTAMP(6)
        AND a.status = 'active' AND sub.expires_at > UTC_TIMESTAMP(6) LIMIT 1`,
		security.SHA256(strings.TrimPrefix(authorization, "Bearer "))).Scan(&identity.AccountID, &identity.TokenID)
	if err != nil {
		writeGatewayError(w, http.StatusUnauthorized, "unauthorized", "远程 Agent 凭证无效或套餐已到期")
		return nil, false
	}
	return &identity, true
}

func (s *Server) loadDefaultAIProvider(ctx context.Context) (providerSecret, string, error) {
	var providerID string
	err := s.db.QueryRowContext(ctx, `SELECT p.id FROM ai_provider_configs p
      JOIN admin_accounts a ON a.id = p.admin_id WHERE a.status = 'active' AND p.enabled = TRUE
      ORDER BY (p.name = ?) DESC, p.updated_at DESC LIMIT 1`, defaultAIProviderName).Scan(&providerID)
	if err != nil {
		return providerSecret{}, "", err
	}
	return s.loadProvider(ctx, providerID, "", true)
}

func writeGatewayError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, map[string]any{"error": map[string]any{
		"message": message, "type": "daylink_gateway_error", "code": code,
	}})
}

func writeAIGatewayEntitlementError(w http.ResponseWriter, err error) bool {
	var entitlementError *aiEntitlementError
	if !errors.As(err, &entitlementError) {
		return false
	}
	writeGatewayError(w, http.StatusPaymentRequired, entitlementError.Code, entitlementError.Message)
	return true
}

type flushingWriter struct {
	writer  io.Writer
	flusher http.Flusher
}

func (w *flushingWriter) Write(content []byte) (int, error) {
	n, err := w.writer.Write(content)
	w.flusher.Flush()
	return n, err
}
