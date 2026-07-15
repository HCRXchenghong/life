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
	identity, ok := s.requireApp(w, r)
	if !ok {
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
	models, err := s.listProviderModels(r.Context(), provider.ID, true)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	preference, err := s.resolveAISelection(r.Context(), identity.AccountID, providerSecret{publicProvider: provider}, "", "")
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "ai_unavailable", "AI 模型目录暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"provider": map[string]any{
		"id": provider.ID, "name": provider.Name, "kind": "daylinkGateway",
		"baseUrl": strings.TrimRight(s.cfg.PublicOrigin, "/") + "/api", "textModel": provider.TextModel,
		"imageModel": provider.ImageModel, "enabled": true, "models": models,
		"selectedTextModel": preference.TextModel, "reasoningEffort": preference.ReasoningEffort,
		"reasoningEfforts": supportedAIReasoningEfforts,
	}})
}

func (s *Server) handleAppAIPreferences(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	var input publicAIPreference
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "AI 模型偏好无效")
		return
	}
	provider, _, err := s.loadDefaultAIProvider(r.Context())
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "ai_unavailable", "AI 服务暂时不可用")
		return
	}
	preference, err := s.resolveAISelection(r.Context(), identity.AccountID, provider, input.TextModel, input.ReasoningEffort)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_ai_preference", "所选模型或推理强度不可用")
		return
	}
	_, err = s.db.ExecContext(r.Context(), `INSERT INTO app_ai_preferences
      (account_id, provider_id, text_model, reasoning_effort) VALUES (?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE provider_id = VALUES(provider_id), text_model = VALUES(text_model),
      reasoning_effort = VALUES(reasoning_effort)`, identity.AccountID, provider.ID,
		preference.TextModel, preference.ReasoningEffort)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "模型偏好保存失败")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "ai_preference.update", "app_account", identity.AccountID, "allowed", "low")
	writeJSON(w, http.StatusOK, map[string]any{"preference": preference})
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
		var discoveryError *providerDiscoveryError
		if errors.As(err, &discoveryError) {
			writeError(w, http.StatusBadGateway, discoveryError.Code, discoveryError.Message)
		} else {
			writeError(w, http.StatusBadGateway, "provider_discovery_failed", "模型目录请求失败，请检查 API 地址和网络")
		}
		return
	}
	textModel, imageModel, ok := selectProviderModels(models)
	if !ok {
		writeError(w, http.StatusBadGateway, "provider_models_unsupported", "该 API 未提供可用的对话模型")
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
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	if status == http.StatusCreated {
		_, err = tx.ExecContext(r.Context(), `INSERT INTO ai_provider_configs
        (id, admin_id, name, kind, base_url, text_model, image_model, api_key_ciphertext,
         api_key_nonce, api_key_hint, enabled) VALUES (?, ?, ?, 'openai_responses', ?, ?, NULLIF(?, ''), ?, ?, ?, TRUE)`,
			providerID, identity.ID, defaultAIProviderName, baseURL, textModel, imageModel,
			ciphertext, nonce, secretHint(key))
	} else {
		_, err = tx.ExecContext(r.Context(), `UPDATE ai_provider_configs SET name = ?, kind = 'openai_responses',
		base_url = ?, text_model = ?, image_model = NULLIF(?, ''), api_key_ciphertext = ?, api_key_nonce = ?,
        api_key_hint = ?, enabled = TRUE WHERE id = ? AND admin_id = ?`, defaultAIProviderName,
			baseURL, textModel, imageModel, ciphertext, nonce, secretHint(key), providerID, identity.ID)
	}
	if err != nil {
		writeError(w, http.StatusConflict, "provider_save_failed", "AI 配置保存失败")
		return
	}
	if _, err = tx.ExecContext(r.Context(), "UPDATE ai_provider_models SET enabled = FALSE WHERE provider_id = ?", providerID); err == nil {
		for _, modelID := range models {
			_, err = tx.ExecContext(r.Context(), `INSERT INTO ai_provider_models
          (provider_id, model_id, kind, enabled) VALUES (?, ?, ?, TRUE)
          ON DUPLICATE KEY UPDATE kind = VALUES(kind), enabled = TRUE, discovered_at = UTC_TIMESTAMP(6)`,
				providerID, modelID, classifyProviderModel(modelID))
			if err != nil {
				break
			}
		}
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "provider_save_failed", "AI 模型目录保存失败")
		return
	}
	if err = tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "provider_save_failed", "AI 模型目录保存失败")
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
		return nil, &providerDiscoveryError{Code: "provider_unreachable", Message: "无法连接 API 地址，请检查地址、DNS 和网络"}
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		_, _ = io.Copy(io.Discard, io.LimitReader(response.Body, 64<<10))
		switch response.StatusCode {
		case http.StatusUnauthorized, http.StatusForbidden:
			return nil, &providerDiscoveryError{Code: "provider_auth_failed", Message: "API Key 被上游拒绝（HTTP 401/403），请更换有效 Key"}
		case http.StatusNotFound:
			return nil, &providerDiscoveryError{Code: "provider_models_not_found", Message: "API 地址下没有 /models 接口，请确认地址包含正确的 /v1 路径"}
		case http.StatusTooManyRequests:
			return nil, &providerDiscoveryError{Code: "provider_rate_limited", Message: "上游限制了模型目录请求，请稍后重试"}
		default:
			return nil, &providerDiscoveryError{Code: "provider_discovery_failed", Message: "上游拒绝模型目录请求"}
		}
	}
	raw, err := io.ReadAll(io.LimitReader(response.Body, (2<<20)+1))
	if err != nil || len(raw) == 0 || len(raw) > 2<<20 {
		return nil, &providerDiscoveryError{Code: "provider_models_invalid", Message: "上游返回的模型目录过大或无效"}
	}
	entries, err := providerModelEntries(raw)
	if err != nil {
		return nil, &providerDiscoveryError{Code: "provider_models_invalid", Message: "上游返回的模型目录不是兼容的 JSON 结构"}
	}
	models := make([]string, 0, len(entries))
	for _, entry := range entries {
		id := strings.TrimSpace(entry)
		if validProviderModelID(id) && !slices.Contains(models, id) {
			models = append(models, id)
		}
		if len(models) >= 2_000 {
			break
		}
	}
	if len(models) == 0 {
		return nil, &providerDiscoveryError{Code: "provider_models_empty", Message: "上游模型目录为空"}
	}
	return models, nil
}

func validProviderModelID(id string) bool {
	if id == "" || len(id) > 120 {
		return false
	}
	for _, character := range id {
		if !((character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z') ||
			(character >= '0' && character <= '9') || strings.ContainsRune("-._:/", character)) {
			return false
		}
	}
	return true
}

func selectProviderModels(models []string) (string, string, bool) {
	text := selectPreferredModel(models, []string{
		"gpt-5.6", "gpt-5.4", "gpt-5.3-codex", "gpt-5.2", "gpt-5", "gpt-4.1",
	}, func(id string) bool {
		return classifyProviderModel(id) == "text"
	})
	image := selectPreferredModel(models, []string{
		"gpt-image-2", "gpt-image-1.5", "gpt-image-1", "gpt-image-1-mini", "dall-e-3",
	}, func(id string) bool {
		return classifyProviderModel(id) == "image"
	})
	return text, image, text != ""
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

type providerDiscoveryError struct {
	Code    string
	Message string
}

func (e *providerDiscoveryError) Error() string { return e.Code }

func providerModelEntries(raw []byte) ([]string, error) {
	var root any
	if err := json.Unmarshal(raw, &root); err != nil {
		return nil, err
	}
	var entries []any
	switch value := root.(type) {
	case []any:
		entries = value
	case map[string]any:
		candidate := value["data"]
		if candidate == nil {
			candidate = value["models"]
		}
		entries, _ = candidate.([]any)
	}
	if entries == nil {
		return nil, errors.New("missing model list")
	}
	models := make([]string, 0, len(entries))
	for _, entry := range entries {
		switch value := entry.(type) {
		case string:
			models = append(models, value)
		case map[string]any:
			if id, ok := value["id"].(string); ok {
				models = append(models, id)
			}
		}
	}
	return models, nil
}
