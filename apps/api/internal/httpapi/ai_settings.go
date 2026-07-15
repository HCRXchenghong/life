package httpapi

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/url"
	"slices"
	"strings"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

const defaultAIProviderName = "Daylink AI"

func (s *Server) handleAdminAISettings(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		s.getAdminAISettings(w, r, identity)
		return
	}
	if !s.requireSameOrigin(w, r) {
		return
	}
	s.saveAdminAISettings(w, r, identity)
}

func (s *Server) handleAppAISettings(w http.ResponseWriter, r *http.Request) {
	if _, ok := s.requireApp(w, r); !ok {
		return
	}
	var provider publicProvider
	var imageModel sql.NullString
	err := s.db.QueryRowContext(r.Context(), `SELECT p.id, p.name, p.text_model, p.image_model
      FROM ai_provider_configs p JOIN admin_accounts a ON a.id = p.admin_id
      WHERE a.status = 'active' AND p.enabled = TRUE
      ORDER BY (p.name = ?) DESC, p.updated_at DESC LIMIT 1`, defaultAIProviderName).
		Scan(&provider.ID, &provider.Name, &provider.TextModel, &imageModel)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "ai_unavailable", "AI 服务尚未配置")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if imageModel.Valid {
		provider.ImageModel = &imageModel.String
	}
	writeJSON(w, http.StatusOK, map[string]any{"provider": map[string]any{
		"id": provider.ID, "name": provider.Name, "kind": "daylinkGateway",
		"baseUrl": strings.TrimRight(s.cfg.PublicOrigin, "/") + "/api", "textModel": provider.TextModel,
		"imageModel": provider.ImageModel, "enabled": true,
	}})
}

func (s *Server) getAdminAISettings(w http.ResponseWriter, r *http.Request, identity *adminIdentity) {
	provider, err := s.defaultProviderMetadata(r.Context(), identity.ID)
	if errors.Is(err, sql.ErrNoRows) {
		writeJSON(w, http.StatusOK, map[string]any{"setting": nil})
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"setting": provider})
}

func (s *Server) saveAdminAISettings(w http.ResponseWriter, r *http.Request, identity *adminIdentity) {
	if retry, err := s.consumeRateLimit(r.Context(), r, "ai_settings_admin", identity.ID, 20); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "AI 配置操作过于频繁")
		return
	}
	var input struct {
		BaseURL string `json:"baseUrl"`
		APIKey  string `json:"apiKey,omitempty"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "AI 配置无效")
		return
	}
	baseURL, err := normalizeAIBaseURL(input.BaseURL)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if strings.ContainsAny(input.APIKey, "\r\n\x00") || len(input.APIKey) > 4096 {
		writeError(w, http.StatusBadRequest, "invalid_request", "API Key 无效")
		return
	}

	providerID, existingKey, err := s.defaultProviderSecret(r.Context(), identity.ID)
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	key := input.APIKey
	if key == "" {
		key = existingKey
	}
	if len(key) < 4 {
		writeError(w, http.StatusBadRequest, "invalid_request", "首次配置必须填写 API Key")
		return
	}
	models, err := s.discoverProviderModels(r.Context(), baseURL, key)
	if err != nil {
		writeError(w, http.StatusBadGateway, "provider_discovery_failed", "无法自动识别模型，请检查 API 地址和 API Key")
		return
	}
	textModel, imageModel, ok := selectProviderModels(models)
	if !ok {
		writeError(w, http.StatusBadGateway, "provider_models_unsupported", "该 API 未提供可用的对话与生图模型")
		return
	}

	status := http.StatusOK
	if providerID == "" {
		providerID, err = security.RandomID()
		if err != nil {
			writeError(w, http.StatusInternalServerError, "provider_save_failed", "暂时无法保存 AI 配置")
			return
		}
		status = http.StatusCreated
	}
	ciphertext, nonce, err := security.Encrypt(s.cfg.AIMasterKey, "provider:"+providerID, []byte(key))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "provider_save_failed", "暂时无法保存 AI 配置")
		return
	}
	if status == http.StatusCreated {
		_, err = s.db.ExecContext(r.Context(), `INSERT INTO ai_provider_configs
        (id, admin_id, name, kind, base_url, text_model, image_model, api_key_ciphertext,
         api_key_nonce, api_key_hint, enabled) VALUES (?, ?, ?, 'openai_responses', ?, ?, ?, ?, ?, ?, TRUE)`,
			providerID, identity.ID, defaultAIProviderName, baseURL, textModel, imageModel,
			ciphertext, nonce, secretHint(key))
	} else {
		_, err = s.db.ExecContext(r.Context(), `UPDATE ai_provider_configs SET name = ?, kind = 'openai_responses',
        base_url = ?, text_model = ?, image_model = ?, api_key_ciphertext = ?, api_key_nonce = ?,
        api_key_hint = ?, enabled = TRUE WHERE id = ? AND admin_id = ?`, defaultAIProviderName,
			baseURL, textModel, imageModel, ciphertext, nonce, secretHint(key), providerID, identity.ID)
	}
	if err != nil {
		writeError(w, http.StatusConflict, "provider_save_failed", "AI 配置保存失败")
		return
	}
	provider, err := s.providerMetadata(r.Context(), providerID, identity.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "provider_save_failed", "AI 配置保存失败")
		return
	}
	s.audit(r.Context(), identity.Actor, "ai_provider.save", "ai_provider", providerID, "allowed", "high")
	writeJSON(w, status, map[string]any{"setting": provider})
}

func (s *Server) defaultProviderMetadata(ctx context.Context, adminID string) (publicProvider, error) {
	var id string
	err := s.db.QueryRowContext(ctx, `SELECT id FROM ai_provider_configs WHERE admin_id = ?
      ORDER BY (name = ?) DESC, updated_at DESC LIMIT 1`, adminID, defaultAIProviderName).Scan(&id)
	if err != nil {
		return publicProvider{}, err
	}
	return s.providerMetadata(ctx, id, adminID)
}

func (s *Server) loadDefaultProviderForApp(ctx context.Context, requestedID string) (providerSecret, string, error) {
	var providerID string
	err := s.db.QueryRowContext(ctx, `SELECT p.id FROM ai_provider_configs p
      JOIN admin_accounts a ON a.id = p.admin_id WHERE a.status = 'active' AND p.enabled = TRUE
      ORDER BY (p.name = ?) DESC, p.updated_at DESC LIMIT 1`, defaultAIProviderName).Scan(&providerID)
	if err != nil || providerID != requestedID {
		return providerSecret{}, "", sql.ErrNoRows
	}
	return s.loadProvider(ctx, providerID, "", true)
}

func (s *Server) defaultProviderSecret(ctx context.Context, adminID string) (string, string, error) {
	var id string
	err := s.db.QueryRowContext(ctx, `SELECT id FROM ai_provider_configs WHERE admin_id = ?
      ORDER BY (name = ?) DESC, updated_at DESC LIMIT 1`, adminID, defaultAIProviderName).Scan(&id)
	if err != nil {
		return "", "", err
	}
	_, key, err := s.loadProvider(ctx, id, adminID, false)
	return id, key, err
}

func normalizeAIBaseURL(raw string) (string, error) {
	validated, err := validatePublicHTTPSBaseURL(raw)
	if err != nil {
		return "", err
	}
	parsed, err := url.Parse(validated)
	if err != nil {
		return "", errors.New("API 地址无效")
	}
	if parsed.EscapedPath() == "" || parsed.EscapedPath() == "/" {
		parsed.Path = "/v1"
	}
	return strings.TrimRight(parsed.String(), "/"), nil
}

func (s *Server) discoverProviderModels(ctx context.Context, baseURL, apiKey string) ([]string, error) {
	request, err := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(baseURL, "/")+"/models", nil)
	if err != nil {
		return nil, err
	}
	request.Header.Set("Authorization", "Bearer "+apiKey)
	request.Header.Set("Accept", "application/json")
	response, err := s.client.Do(request)
	if err != nil {
		return nil, errors.New("provider unreachable")
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 64<<10))
		return nil, errors.New("provider rejected model discovery")
	}
	var payload struct {
		Data []struct {
			ID string `json:"id"`
		} `json:"data"`
	}
	if err := json.NewDecoder(io.LimitReader(response.Body, 2<<20)).Decode(&payload); err != nil {
		return nil, errors.New("provider returned invalid models")
	}
	models := make([]string, 0, len(payload.Data))
	for _, model := range payload.Data {
		id := strings.TrimSpace(model.ID)
		if id != "" && len(id) <= 120 && !slices.Contains(models, id) {
			models = append(models, id)
		}
		if len(models) >= 2_000 {
			break
		}
	}
	if len(models) == 0 {
		return nil, errors.New("provider returned no models")
	}
	return models, nil
}

func selectProviderModels(models []string) (string, string, bool) {
	text := selectPreferredModel(models, []string{
		"gpt-5.6", "gpt-5.4", "gpt-5.3-codex", "gpt-5.2", "gpt-5", "gpt-4.1",
	}, func(id string) bool {
		lower := strings.ToLower(id)
		return strings.HasPrefix(lower, "gpt-") && !strings.Contains(lower, "image") &&
			!strings.Contains(lower, "audio") && !strings.Contains(lower, "tts") && !strings.Contains(lower, "transcribe")
	})
	image := selectPreferredModel(models, []string{
		"gpt-image-2", "gpt-image-1.5", "gpt-image-1", "gpt-image-1-mini", "dall-e-3",
	}, func(id string) bool {
		lower := strings.ToLower(id)
		return strings.Contains(lower, "gpt-image") || strings.HasPrefix(lower, "dall-e")
	})
	return text, image, text != "" && image != ""
}

func selectPreferredModel(models, preferred []string, fallback func(string) bool) string {
	for _, candidate := range preferred {
		for _, model := range models {
			if strings.EqualFold(model, candidate) {
				return model
			}
		}
	}
	for _, model := range models {
		if fallback(model) {
			return model
		}
	}
	return ""
}
