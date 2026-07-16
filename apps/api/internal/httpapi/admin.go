package httpapi

import (
	"context"
	"database/sql"
	"encoding/base64"
	"encoding/csv"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

type publicAppAccount struct {
	ID                     string                `json:"id"`
	Username               string                `json:"username"`
	Status                 string                `json:"status"`
	PasswordChangeRequired bool                  `json:"passwordChangeRequired"`
	LockedUntil            *time.Time            `json:"lockedUntil"`
	LastLoginAt            *time.Time            `json:"lastLoginAt"`
	CreatedAt              time.Time             `json:"createdAt"`
	Subscription           *publicAISubscription `json:"subscription"`
}

type publicProvider struct {
	ID         string          `json:"id"`
	Name       string          `json:"name"`
	Kind       string          `json:"kind"`
	BaseURL    string          `json:"baseUrl"`
	TextModel  string          `json:"textModel"`
	ImageModel *string         `json:"imageModel"`
	APIKeyHint string          `json:"apiKeyHint"`
	Enabled    bool            `json:"enabled"`
	UpdatedAt  time.Time       `json:"updatedAt"`
	Models     []publicAIModel `json:"models,omitempty"`
}

type publicAuditEvent struct {
	ID              string    `json:"id"`
	ActorLabel      string    `json:"actorLabel"`
	ActionLabel     string    `json:"actionLabel"`
	TargetTypeLabel string    `json:"targetTypeLabel"`
	Outcome         string    `json:"outcome"`
	OutcomeLabel    string    `json:"outcomeLabel"`
	Risk            string    `json:"risk"`
	RiskLabel       string    `json:"riskLabel"`
	CreatedAt       time.Time `json:"createdAt"`
}

func (s *Server) handleAdminOverview(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	data, err := s.adminOverviewData(r.Context(), identity)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, data)
}

func (s *Server) handleAdminOverviewEvents(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, http.StatusInternalServerError, "streaming_unavailable", "实时状态暂时不可用")
		return
	}
	w.Header().Set("Content-Type", "text/event-stream; charset=utf-8")
	w.Header().Set("Cache-Control", "no-cache, no-store")
	w.Header().Set("X-Accel-Buffering", "no")
	_, _ = io.WriteString(w, "retry: 1000\n\n")
	flusher.Flush()

	send := func() bool {
		data, err := s.adminOverviewData(r.Context(), identity)
		if err != nil {
			_, _ = io.WriteString(w, "event: unavailable\ndata: {}\n\n")
			flusher.Flush()
			return false
		}
		encoded, err := json.Marshal(data)
		if err != nil {
			return false
		}
		if _, err := fmt.Fprintf(w, "event: overview\ndata: %s\n\n", encoded); err != nil {
			return false
		}
		flusher.Flush()
		return true
	}
	if !send() {
		return
	}
	ticker := time.NewTicker(time.Second)
	// The HTTP server has a bounded write deadline. EventSource reconnects before
	// that deadline, preserving real-time delivery without unbounded handlers.
	lifetime := time.NewTimer(2 * time.Minute)
	defer ticker.Stop()
	defer lifetime.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case <-lifetime.C:
			return
		case <-ticker.C:
			if !send() {
				return
			}
		}
	}
}

func (s *Server) adminOverviewData(ctx context.Context, identity *adminIdentity) (map[string]any, error) {
	var accounts, providers int
	if err := s.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM app_accounts").Scan(&accounts); err != nil {
		return nil, err
	}
	if err := s.db.QueryRowContext(ctx, "SELECT COUNT(*) FROM ai_provider_configs WHERE admin_id = ?", identity.ID).Scan(&providers); err != nil {
		return nil, err
	}
	metrics := s.collectServerMetrics(ctx)
	return map[string]any{
		"username": identity.Username, "appAccountCount": accounts, "aiProviderCount": providers,
		"servers": []serverMetrics{metrics}, "supportedSystems": []string{"windows", "macos", "ubuntu"},
	}, nil
}

func (s *Server) handleAdminAppAccounts(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if r.Method != http.MethodGet && !s.requireSameOrigin(w, r) {
		return
	}
	switch r.Method {
	case http.MethodGet:
		s.listAppAccounts(w, r)
	case http.MethodPost:
		s.createAppAccount(w, r, identity)
	case http.MethodPatch:
		s.updateAppAccount(w, r, identity)
	}
}

func (s *Server) listAppAccounts(w http.ResponseWriter, r *http.Request) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT a.id, a.username, a.status, a.password_change_required,
      a.locked_until, a.last_login_at, a.created_at, sub.plan, sub.card_type, sub.starts_at, sub.expires_at
      FROM app_accounts a LEFT JOIN app_ai_subscriptions sub ON sub.account_id = a.id
      ORDER BY a.created_at DESC LIMIT 500`)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer rows.Close()
	accounts := make([]publicAppAccount, 0)
	for rows.Next() {
		var account publicAppAccount
		var locked, login, subscriptionStart, subscriptionExpiry sql.NullTime
		var subscriptionPlan, cardType sql.NullString
		if err := rows.Scan(&account.ID, &account.Username, &account.Status, &account.PasswordChangeRequired,
			&locked, &login, &account.CreatedAt, &subscriptionPlan, &cardType, &subscriptionStart, &subscriptionExpiry); err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		if locked.Valid {
			account.LockedUntil = &locked.Time
		}
		if login.Valid {
			account.LastLoginAt = &login.Time
		}
		if subscriptionPlan.Valid && cardType.Valid && subscriptionStart.Valid && subscriptionExpiry.Valid {
			account.Subscription = &publicAISubscription{
				Plan: subscriptionPlan.String, CardType: cardType.String, StartsAt: subscriptionStart.Time,
				ExpiresAt: subscriptionExpiry.Time, Active: subscriptionExpiry.Time.After(time.Now().UTC()),
			}
		}
		accounts = append(accounts, account)
	}
	if rows.Err() != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"accounts": accounts})
}

func (s *Server) createAppAccount(w http.ResponseWriter, r *http.Request, identity *adminIdentity) {
	if retry, err := s.consumeRateLimit(r.Context(), r, "app_account_admin", identity.ID, 30); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "操作过于频繁")
		return
	}
	var input struct {
		Username        string `json:"username"`
		Password        string `json:"password"`
		ConfirmPassword string `json:"confirmPassword"`
	}
	if err := decodeJSON(r, &input); err != nil || input.Password != input.ConfirmPassword {
		writeError(w, http.StatusBadRequest, "invalid_request", "两次输入的密码不一致")
		return
	}
	username, err := security.ValidateUsername(input.Username)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	digest, err := security.HashPassword(input.Password, "app", s.cfg.AuthMasterKey)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	id, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "account_create_failed", "暂时无法创建账号")
		return
	}
	now := time.Now().UTC()
	_, err = s.db.ExecContext(r.Context(), `INSERT INTO app_accounts
      (id, username, username_canonical, password_algorithm, password_hash, password_salt,
       password_iterations, password_change_required, status, password_changed_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, TRUE, 'active', ?)`, id, username, strings.ToLower(username),
		digest.Algorithm, digest.Hash, digest.Salt, digest.Iterations, now)
	if err != nil {
		writeError(w, http.StatusConflict, "username_unavailable", "该 App 账号已存在")
		return
	}
	s.audit(r.Context(), identity.Actor, "app_account.create", "app_account", id, "allowed", "high")
	writeJSON(w, http.StatusCreated, map[string]any{"account": publicAppAccount{
		ID: id, Username: username, Status: "active", PasswordChangeRequired: true, CreatedAt: now,
	}})
}

func (s *Server) updateAppAccount(w http.ResponseWriter, r *http.Request, identity *adminIdentity) {
	if retry, err := s.consumeRateLimit(r.Context(), r, "app_account_admin", identity.ID, 30); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "操作过于频繁")
		return
	}
	var input struct {
		ID              string `json:"id"`
		Action          string `json:"action"`
		Password        string `json:"password,omitempty"`
		ConfirmPassword string `json:"confirmPassword,omitempty"`
	}
	if err := decodeJSON(r, &input); err != nil || input.ID == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var result sql.Result
	switch input.Action {
	case "enable":
		result, err = tx.ExecContext(r.Context(), "UPDATE app_accounts SET status = 'active', failed_login_count = 0, locked_until = NULL WHERE id = ?", input.ID)
	case "disable":
		result, err = tx.ExecContext(r.Context(), "UPDATE app_accounts SET status = 'disabled' WHERE id = ?", input.ID)
		if err == nil {
			_, err = tx.ExecContext(r.Context(), "UPDATE app_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE account_id = ? AND revoked_at IS NULL", input.ID)
		}
		if err == nil {
			_, err = tx.ExecContext(r.Context(), "UPDATE ai_gateway_tokens SET revoked_at = UTC_TIMESTAMP(6) WHERE account_id = ? AND revoked_at IS NULL", input.ID)
		}
	case "reset_password":
		if input.Password != input.ConfirmPassword {
			err = errors.New("两次输入的密码不一致")
			break
		}
		var digest security.PasswordDigest
		digest, err = security.HashPassword(input.Password, "app", s.cfg.AuthMasterKey)
		if err == nil {
			result, err = tx.ExecContext(r.Context(), `UPDATE app_accounts SET password_algorithm = ?, password_hash = ?,
          password_salt = ?, password_iterations = ?, password_change_required = TRUE,
          failed_login_count = 0, locked_until = NULL, password_changed_at = UTC_TIMESTAMP(6) WHERE id = ?`,
				digest.Algorithm, digest.Hash, digest.Salt, digest.Iterations, input.ID)
		}
		if err == nil {
			_, err = tx.ExecContext(r.Context(), "UPDATE app_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE account_id = ? AND revoked_at IS NULL", input.ID)
		}
		if err == nil {
			_, err = tx.ExecContext(r.Context(), "UPDATE ai_gateway_tokens SET revoked_at = UTC_TIMESTAMP(6) WHERE account_id = ? AND revoked_at IS NULL", input.ID)
		}
	default:
		err = errors.New("不支持的账号操作")
	}
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if changed, _ := result.RowsAffected(); changed != 1 {
		writeError(w, http.StatusNotFound, "not_found", "App 账号不存在")
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "update_failed", "账号更新失败")
		return
	}
	if input.Action == "disable" {
		s.syncHub.revoke(input.ID, "account_disabled")
	} else if input.Action == "reset_password" {
		s.syncHub.revoke(input.ID, "credentials_changed")
	}
	s.audit(r.Context(), identity.Actor, "app_account."+input.Action, "app_account", input.ID, "allowed", "critical")
	writeJSON(w, http.StatusOK, map[string]any{"updated": true})
}

func (s *Server) handleAdminProviders(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		s.listProviders(w, r, identity)
		return
	}
	if !s.requireSameOrigin(w, r) {
		return
	}
	s.saveProvider(w, r, identity)
}

func (s *Server) listProviders(w http.ResponseWriter, r *http.Request, identity *adminIdentity) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, name, kind, base_url, text_model, image_model,
      api_key_hint, enabled, updated_at FROM ai_provider_configs WHERE admin_id = ? ORDER BY updated_at DESC`, identity.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer rows.Close()
	providers := make([]publicProvider, 0)
	for rows.Next() {
		var provider publicProvider
		var image sql.NullString
		if err := rows.Scan(&provider.ID, &provider.Name, &provider.Kind, &provider.BaseURL, &provider.TextModel,
			&image, &provider.APIKeyHint, &provider.Enabled, &provider.UpdatedAt); err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		if image.Valid {
			provider.ImageModel = &image.String
		}
		providers = append(providers, provider)
	}
	if rows.Err() != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"providers": providers})
}

func (s *Server) saveProvider(w http.ResponseWriter, r *http.Request, identity *adminIdentity) {
	if retry, err := s.consumeRateLimit(r.Context(), r, "ai_provider_admin", identity.ID, 30); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "操作过于频繁")
		return
	}
	var input struct {
		ID         string `json:"id,omitempty"`
		Name       string `json:"name"`
		Kind       string `json:"kind"`
		BaseURL    string `json:"baseUrl"`
		TextModel  string `json:"textModel"`
		ImageModel string `json:"imageModel,omitempty"`
		APIKey     string `json:"apiKey,omitempty"`
		Enabled    bool   `json:"enabled"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	input.Name = strings.TrimSpace(input.Name)
	input.TextModel = strings.TrimSpace(input.TextModel)
	input.ImageModel = strings.TrimSpace(input.ImageModel)
	if len(input.Name) < 1 || len(input.Name) > 80 || len(input.TextModel) < 1 || len(input.TextModel) > 120 || (input.Kind != "openai_responses" && input.Kind != "openai_compatible") {
		writeError(w, http.StatusBadRequest, "invalid_request", "AI 服务配置无效")
		return
	}
	baseURL, err := validatePublicHTTPSBaseURL(input.BaseURL)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	status := http.StatusOK
	providerID := input.ID
	if providerID == "" {
		if len(input.APIKey) < 4 || len(input.APIKey) > 4096 || strings.ContainsAny(input.APIKey, "\r\n\x00") {
			writeError(w, http.StatusBadRequest, "invalid_request", "API Key 无效")
			return
		}
		providerID, err = security.RandomID()
		if err != nil {
			writeError(w, http.StatusInternalServerError, "provider_save_failed", "暂时无法保存 AI 服务")
			return
		}
		ciphertext, nonce, encryptErr := security.Encrypt(s.cfg.AIMasterKey, "provider:"+providerID, []byte(input.APIKey))
		if encryptErr != nil {
			writeError(w, http.StatusInternalServerError, "provider_save_failed", "暂时无法保存 AI 服务")
			return
		}
		_, err = s.db.ExecContext(r.Context(), `INSERT INTO ai_provider_configs
        (id, admin_id, name, kind, base_url, text_model, image_model, api_key_ciphertext,
         api_key_nonce, api_key_hint, enabled) VALUES (?, ?, ?, ?, ?, ?, NULLIF(?, ''), ?, ?, ?, ?)`,
			providerID, identity.ID, input.Name, input.Kind, baseURL, input.TextModel, input.ImageModel,
			ciphertext, nonce, secretHint(input.APIKey), input.Enabled)
		status = http.StatusCreated
	} else if input.APIKey != "" {
		if strings.ContainsAny(input.APIKey, "\r\n\x00") || len(input.APIKey) > 4096 {
			writeError(w, http.StatusBadRequest, "invalid_request", "API Key 无效")
			return
		}
		ciphertext, nonce, encryptErr := security.Encrypt(s.cfg.AIMasterKey, "provider:"+providerID, []byte(input.APIKey))
		if encryptErr != nil {
			writeError(w, http.StatusInternalServerError, "provider_save_failed", "暂时无法保存 AI 服务")
			return
		}
		_, err = s.db.ExecContext(r.Context(), `UPDATE ai_provider_configs SET name = ?, kind = ?, base_url = ?,
        text_model = ?, image_model = NULLIF(?, ''), api_key_ciphertext = ?, api_key_nonce = ?,
        api_key_hint = ?, enabled = ? WHERE id = ? AND admin_id = ?`, input.Name, input.Kind, baseURL,
			input.TextModel, input.ImageModel, ciphertext, nonce, secretHint(input.APIKey), input.Enabled, providerID, identity.ID)
	} else {
		_, err = s.db.ExecContext(r.Context(), `UPDATE ai_provider_configs SET name = ?, kind = ?, base_url = ?,
        text_model = ?, image_model = NULLIF(?, ''), enabled = ? WHERE id = ? AND admin_id = ?`,
			input.Name, input.Kind, baseURL, input.TextModel, input.ImageModel, input.Enabled, providerID, identity.ID)
	}
	if err != nil {
		writeError(w, http.StatusConflict, "provider_name_unavailable", "同名 AI 服务已存在")
		return
	}
	provider, err := s.providerMetadata(r.Context(), providerID, identity.ID)
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "AI 服务不存在")
		return
	}
	s.audit(r.Context(), identity.Actor, "ai_provider.save", "ai_provider", providerID, "allowed", "high")
	writeJSON(w, status, map[string]any{"provider": provider})
}

func (s *Server) providerMetadata(ctx context.Context, providerID, adminID string) (publicProvider, error) {
	var provider publicProvider
	var image sql.NullString
	err := s.db.QueryRowContext(ctx, `SELECT id, name, kind, base_url, text_model, image_model,
      api_key_hint, enabled, updated_at FROM ai_provider_configs WHERE id = ? AND admin_id = ?`, providerID, adminID).
		Scan(&provider.ID, &provider.Name, &provider.Kind, &provider.BaseURL, &provider.TextModel,
			&image, &provider.APIKeyHint, &provider.Enabled, &provider.UpdatedAt)
	if image.Valid {
		provider.ImageModel = &image.String
	}
	if err == nil {
		provider.Models, err = s.listProviderModels(ctx, provider.ID, true)
	}
	return provider, err
}

func secretHint(value string) string {
	if len(value) <= 8 {
		return "••••"
	}
	return "••••" + value[len(value)-4:]
}

func (s *Server) handleAdminAudit(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if r.URL.Query().Get("format") == "csv" {
		s.downloadAdminAudit(w, r, identity)
		return
	}
	page := boundedPositiveInt(r.URL.Query().Get("page"), 1, 1, 1_000_000)
	pageSize := boundedPositiveInt(r.URL.Query().Get("pageSize"), 20, 10, 100)
	var total int
	if err := s.db.QueryRowContext(r.Context(), "SELECT COUNT(*) FROM audit_events").Scan(&total); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	totalPages := (total + pageSize - 1) / pageSize
	if totalPages == 0 {
		totalPages = 1
	}
	if page > totalPages {
		page = totalPages
	}
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, actor, action, target_type, outcome, risk, created_at
	      FROM audit_events ORDER BY created_at DESC, id DESC LIMIT ? OFFSET ?`, pageSize, (page-1)*pageSize)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer rows.Close()
	events := make([]publicAuditEvent, 0, pageSize)
	for rows.Next() {
		var id, actor, action, targetType, outcome, risk string
		var createdAt time.Time
		if err := rows.Scan(&id, &actor, &action, &targetType, &outcome, &risk, &createdAt); err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		events = append(events, localizedAuditEvent(id, actor, action, targetType, outcome, risk, createdAt))
	}
	if rows.Err() != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"events": events, "page": page, "pageSize": pageSize, "total": total, "totalPages": totalPages,
	})
}

func (s *Server) downloadAdminAudit(w http.ResponseWriter, r *http.Request, identity *adminIdentity) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, actor, action, target_type, outcome, risk, created_at
	      FROM audit_events ORDER BY created_at DESC, id DESC LIMIT 10000`)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer rows.Close()
	w.Header().Set("Content-Type", "text/csv; charset=utf-8")
	w.Header().Set("Content-Disposition", `attachment; filename="daylink-audit.csv"`)
	w.WriteHeader(http.StatusOK)
	_, _ = io.WriteString(w, "\ufeff")
	writer := csv.NewWriter(w)
	_ = writer.Write([]string{"时间", "操作者", "操作", "对象", "结果", "风险级别"})
	chinaTime := time.FixedZone("Asia/Shanghai", 8*60*60)
	for rows.Next() {
		var id, actor, action, targetType, outcome, risk string
		var createdAt time.Time
		if err := rows.Scan(&id, &actor, &action, &targetType, &outcome, &risk, &createdAt); err != nil {
			return
		}
		event := localizedAuditEvent(id, actor, action, targetType, outcome, risk, createdAt)
		_ = writer.Write([]string{
			event.CreatedAt.In(chinaTime).Format("2006-01-02 15:04:05"), event.ActorLabel,
			event.ActionLabel, event.TargetTypeLabel, event.OutcomeLabel, event.RiskLabel,
		})
	}
	writer.Flush()
	if writer.Error() == nil && rows.Err() == nil {
		s.audit(r.Context(), identity.Actor, "admin.audit.download", "audit_event", "", "allowed", "read_only")
	}
}

func boundedPositiveInt(raw string, fallback, minimum, maximum int) int {
	value, err := strconv.Atoi(raw)
	if err != nil || value < minimum {
		return fallback
	}
	if value > maximum {
		return maximum
	}
	return value
}

func localizedAuditEvent(id, actor, action, targetType, outcome, risk string, createdAt time.Time) publicAuditEvent {
	return publicAuditEvent{
		ID: id, ActorLabel: auditActorLabel(actor), ActionLabel: auditActionLabel(action),
		TargetTypeLabel: auditTargetLabel(targetType), Outcome: outcome, OutcomeLabel: auditOutcomeLabel(outcome),
		Risk: risk, RiskLabel: auditRiskLabel(risk), CreatedAt: createdAt,
	}
}

func auditActorLabel(actor string) string {
	switch {
	case strings.HasPrefix(actor, "admin:"):
		return "后台管理员"
	case strings.HasPrefix(actor, "app:"):
		return "App 用户"
	case strings.HasPrefix(actor, "poll-manager:"):
		return "投票管理员"
	case strings.HasPrefix(actor, "invitation:"):
		return "受邀成员"
	default:
		return "系统"
	}
}

func auditActionLabel(action string) string {
	labels := map[string]string{
		"admin.enrollment.authorize":  "授权管理员初始化",
		"admin.enrollment.started":    "开始绑定双重验证",
		"admin.enrollment.cancelled":  "取消管理员初始化",
		"admin.enrollment.verify":     "验证双重验证码",
		"admin.enrollment.completed":  "完成管理员初始化",
		"admin.login":                 "管理员登录",
		"admin.password.change":       "修改管理员密码",
		"admin.totp.rebind":           "重新绑定双重验证",
		"admin.audit.download":        "下载安全审计日志",
		"app.login":                   "App 账号登录",
		"app.logout":                  "App 账号退出",
		"app.session.refresh":         "刷新 App 会话",
		"app.password.change":         "修改 App 密码",
		"app.e2ee.device.request":     "发起新设备批准",
		"app.e2ee.device.approve":     "批准新设备",
		"app.e2ee.device.reject":      "拒绝新设备",
		"app.e2ee.device.cancel":      "取消新设备批准",
		"app.e2ee.device.consume":     "完成新设备恢复",
		"app_account.create":          "创建 App 账号",
		"app_account.enable":          "启用 App 账号",
		"app_account.disable":         "停用 App 账号",
		"app_account.reset_password":  "重置 App 密码",
		"app_invitation.create":       "创建一次性邀请",
		"app_invitation.consume":      "使用一次性邀请",
		"app_subscription.grant":      "发放 AI 套餐",
		"app_subscription.revoke":     "取消 AI 套餐",
		"ai_provider.save":            "保存 AI 服务配置",
		"ai_provider.test":            "测试 AI 服务连接",
		"ai_plan_limits.update":       "更新 AI 套餐额度",
		"ai_gateway_token.create":     "创建远程 Agent 凭证",
		"ai_gateway.response":         "调用 AI 对话服务",
		"ai_gateway.image":            "调用 AI 生图服务",
		"ai_gateway.remote.responses": "远程 Agent 调用 AI 对话",
		"ai_gateway.remote.image":     "远程 Agent 调用 AI 生图",
		"image.generate":              "生成图片",
		"poll.create":                 "创建时间投票",
		"poll.finalize":               "确定投票时间",
	}
	if label, ok := labels[action]; ok {
		return label
	}
	return "其他安全操作"
}

func auditTargetLabel(targetType string) string {
	labels := map[string]string{
		"admin_account": "管理员账号", "admin_session": "管理员会话", "app_account": "App 账号",
		"app_session": "App 会话", "ai_provider": "AI 服务", "generated_asset": "生成图片",
		"share_poll": "时间投票", "audit_event": "安全审计日志", "app_invitation": "App 邀请",
		"ai_gateway_token": "远程 Agent 凭证", "ai_plan": "AI 套餐额度",
		"device_approval": "新设备批准",
	}
	if label, ok := labels[targetType]; ok {
		return label
	}
	return "系统资源"
}

func auditOutcomeLabel(outcome string) string {
	switch outcome {
	case "allowed":
		return "成功"
	case "denied":
		return "已拒绝"
	default:
		return "失败"
	}
}

func auditRiskLabel(risk string) string {
	switch risk {
	case "read_only":
		return "只读"
	case "low":
		return "低"
	case "medium":
		return "中"
	case "high":
		return "高"
	default:
		return "严重"
	}
}

func (s *Server) handleAdminImages(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		rows, err := s.db.QueryContext(r.Context(), `SELECT id, provider_config_id, content_type, byte_size,
        width, height, created_at FROM generated_assets WHERE admin_id = ? ORDER BY created_at DESC LIMIT 50`, identity.ID)
		if err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		defer rows.Close()
		assets := make([]map[string]any, 0)
		for rows.Next() {
			var id, providerID, contentType string
			var bytes int64
			var width, height sql.NullInt64
			var created time.Time
			if err := rows.Scan(&id, &providerID, &contentType, &bytes, &width, &height, &created); err != nil {
				writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
				return
			}
			assets = append(assets, map[string]any{"id": id, "providerConfigId": providerID, "contentType": contentType,
				"byteSize": bytes, "width": nullableInt(width), "height": nullableInt(height), "createdAt": created, "url": "/api/admin/images/" + id})
		}
		if rows.Err() != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"assets": assets})
		return
	}
	if !s.requireSameOrigin(w, r) {
		return
	}
	s.generateAdminImage(w, r, identity)
}

func (s *Server) handleAdminImage(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	var objectKey, contentType string
	id := r.PathValue("id")
	err := s.db.QueryRowContext(r.Context(), "SELECT object_key, content_type FROM generated_assets WHERE id = ? AND admin_id = ?", id, identity.ID).Scan(&objectKey, &contentType)
	if err != nil {
		writeError(w, http.StatusNotFound, "not_found", "图片不存在")
		return
	}
	if objectKey != id+".png" || filepath.Base(objectKey) != objectKey {
		writeError(w, http.StatusNotFound, "asset_missing", "图片文件不存在")
		return
	}
	path := filepath.Join(s.cfg.AssetDirectory, objectKey)
	file, err := os.Open(path)
	if err != nil {
		writeError(w, http.StatusNotFound, "asset_missing", "图片文件不存在")
		return
	}
	defer file.Close()
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Content-Security-Policy", "default-src 'none'")
	_, _ = io.Copy(w, file)
}

func nullableInt(value sql.NullInt64) any {
	if value.Valid {
		return value.Int64
	}
	return nil
}

func parseImageData(value string) ([]byte, error) {
	value = strings.TrimSpace(value)
	const dataPrefix = "data:image/png;base64,"
	if strings.HasPrefix(strings.ToLower(value), dataPrefix) {
		value = value[len(dataPrefix):]
	}
	decoded, err := base64.StdEncoding.DecodeString(value)
	if err != nil {
		decoded, err = base64.RawStdEncoding.DecodeString(value)
	}
	if err != nil {
		return nil, fmt.Errorf("生图服务返回了无效图片")
	}
	return validatePNGImage(decoded)
}

func validatePNGImage(decoded []byte) ([]byte, error) {
	const pngSignature = "\x89PNG\r\n\x1a\n"
	if len(decoded) < len(pngSignature) || len(decoded) > 32<<20 ||
		string(decoded[:len(pngSignature)]) != pngSignature {
		return nil, fmt.Errorf("生图服务返回了无效图片")
	}
	return decoded, nil
}
