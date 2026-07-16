package httpapi

import (
	"context"
	"crypto/subtle"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/config"
	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

const (
	maxJSONBody      = 512 << 10
	adminSessionTTL  = 12 * time.Hour
	appAccessTTL     = 15 * time.Minute
	appRefreshTTL    = 30 * 24 * time.Hour
	enrollmentTTL    = 10 * time.Minute
	rateLimitWindow  = 15 * time.Minute
	rateLimitBlock   = 30 * time.Minute
	adminCookie      = "daylink_admin_session"
	enrollmentCookie = "daylink_admin_enrollment"
	rebindCookie     = "daylink_admin_totp_rebind"
)

type Server struct {
	cfg            config.Config
	db             *sql.DB
	mux            *http.ServeMux
	client         *http.Client
	logger         *slog.Logger
	syncHub        *syncHub
	trustedProxies []*net.IPNet
	assetMutex     sync.Mutex
}

type adminIdentity struct {
	ID       string
	Username string
	Actor    string
}

type appIdentity struct {
	AccountID              string
	SessionID              string
	Username               string
	DeviceName             string
	E2EETrusted            bool
	PasswordChangeRequired bool
}

type contextExecer interface {
	ExecContext(context.Context, string, ...any) (sql.Result, error)
}

type errorEnvelope struct {
	Error apiError `json:"error"`
}

type apiError struct {
	Code    string `json:"code"`
	Message string `json:"message,omitempty"`
}

func New(cfg config.Config, db *sql.DB, logger *slog.Logger) *Server {
	if logger == nil {
		logger = slog.New(slog.NewJSONHandler(os.Stdout, nil))
	}
	s := &Server{
		cfg:     cfg,
		db:      db,
		mux:     http.NewServeMux(),
		logger:  logger,
		syncHub: newSyncHub(),
		client:  newSafeHTTPClient(cfg.UpstreamTimeout),
	}
	for _, raw := range cfg.TrustedProxyCIDRs {
		if _, network, err := net.ParseCIDR(raw); err == nil {
			s.trustedProxies = append(s.trustedProxies, network)
		}
	}
	s.routes()
	s.reconcileInterruptedAIRuns()
	return s
}

func (s *Server) reconcileInterruptedAIRuns() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_, err := s.db.ExecContext(ctx, `UPDATE ai_runs SET status = 'cancelled',
      error_code = 'request_interrupted', error_message = 'Request interrupted before completion',
      completed_at = UTC_TIMESTAMP(6) WHERE status = 'running'`)
	if err != nil {
		s.logger.Warn("unable to reconcile interrupted AI runs")
	}
}

func (s *Server) Handler() http.Handler {
	return s.securityHeaders(s.recoverPanic(s.mux))
}

func (s *Server) routes() {
	s.mux.HandleFunc("GET /api/health", s.handleHealth)
	s.mux.HandleFunc("GET /api/admin/bootstrap", s.handleAdminBootstrap)
	s.mux.HandleFunc("POST /api/auth/setup", s.handleAdminSetup)
	s.mux.HandleFunc("DELETE /api/auth/setup", s.handleAdminSetupCancel)
	s.mux.HandleFunc("GET /api/auth/setup/enrollment", s.handleAdminEnrollment)
	s.mux.HandleFunc("POST /api/auth/setup/verify", s.handleAdminEnrollmentVerify)
	s.mux.HandleFunc("POST /api/auth/login", s.handleAdminLogin)
	s.mux.HandleFunc("POST /api/auth/logout", s.handleAdminLogout)
	s.mux.HandleFunc("POST /api/admin/security/password", s.handleAdminPassword)
	s.mux.HandleFunc("POST /api/admin/security/totp", s.handleAdminTOTP)
	s.mux.HandleFunc("DELETE /api/admin/security/totp", s.handleAdminTOTPCancel)
	s.mux.HandleFunc("GET /api/admin/overview", s.handleAdminOverview)
	s.mux.HandleFunc("GET /api/admin/overview/events", s.handleAdminOverviewEvents)
	s.mux.HandleFunc("GET /api/admin/app-accounts", s.handleAdminAppAccounts)
	s.mux.HandleFunc("POST /api/admin/app-accounts", s.handleAdminAppAccounts)
	s.mux.HandleFunc("PATCH /api/admin/app-accounts", s.handleAdminAppAccounts)
	s.mux.HandleFunc("POST /api/admin/app-invitations", s.handleAdminAppInvitation)
	s.mux.HandleFunc("POST /api/admin/app-subscriptions", s.handleAdminAppSubscription)
	s.mux.HandleFunc("GET /api/invitations/{token}", s.handleAppInvitation)
	s.mux.HandleFunc("POST /api/invitations/{token}", s.handleAppInvitation)
	s.mux.HandleFunc("GET /api/admin/providers", s.handleAdminProviders)
	s.mux.HandleFunc("POST /api/admin/providers", s.handleAdminProviders)
	s.mux.HandleFunc("GET /api/admin/ai-settings", s.handleAdminAISettings)
	s.mux.HandleFunc("POST /api/admin/ai-settings", s.handleAdminAISettings)
	s.mux.HandleFunc("GET /api/admin/ai-plans", s.handleAdminAIPlanLimits)
	s.mux.HandleFunc("POST /api/admin/ai-plans", s.handleAdminAIPlanLimits)
	s.mux.HandleFunc("POST /api/admin/ai-test", s.handleAdminAITest)
	s.mux.HandleFunc("GET /api/admin/audit", s.handleAdminAudit)
	s.mux.HandleFunc("GET /api/admin/images", s.handleAdminImages)
	s.mux.HandleFunc("POST /api/admin/images", s.handleAdminImages)
	s.mux.HandleFunc("GET /api/admin/images/{id}", s.handleAdminImage)
	s.mux.HandleFunc("POST /api/app/auth/login", s.handleAppLogin)
	s.mux.HandleFunc("POST /api/app/auth/refresh", s.handleAppRefresh)
	s.mux.HandleFunc("GET /api/app/auth/session", s.handleAppSession)
	s.mux.HandleFunc("DELETE /api/app/auth/session", s.handleAppSession)
	s.mux.HandleFunc("GET /api/app/auth/devices", s.handleAppDevices)
	s.mux.HandleFunc("DELETE /api/app/auth/devices", s.handleAppDevices)
	s.mux.HandleFunc("DELETE /api/app/auth/devices/{id}", s.handleAppDevice)
	s.mux.HandleFunc("POST /api/app/auth/password", s.handleAppPassword)
	s.mux.HandleFunc("GET /api/app/ai-settings", s.handleAppAISettings)
	s.mux.HandleFunc("PUT /api/app/ai-preferences", s.handleAppAIPreferences)
	s.mux.HandleFunc("GET /api/app/ai-entitlement", s.handleAppAIEntitlement)
	s.mux.HandleFunc("POST /api/app/ai-remote-token", s.handleAppAIRemoteToken)
	s.mux.HandleFunc("POST /api/assistant/responses", s.handleAssistantResponses)
	s.mux.HandleFunc("POST /api/assistant/images", s.handleAssistantImages)
	s.mux.HandleFunc("POST /api/assistant/artifacts", s.handleAssistantArtifact)
	s.mux.HandleFunc("GET /v1/models", s.handleAIGatewayModels)
	s.mux.HandleFunc("POST /v1/responses", s.handleAIGatewayResponses)
	s.mux.HandleFunc("POST /v1/images/generations", s.handleAIGatewayImages)
	s.mux.HandleFunc("GET /api/polls", s.handlePolls)
	s.mux.HandleFunc("POST /api/polls", s.handlePolls)
	s.mux.HandleFunc("GET /api/polls/{token}", s.handlePoll)
	s.mux.HandleFunc("POST /api/polls/{token}/votes", s.handlePollVotes)
	s.mux.HandleFunc("POST /api/polls/{token}/finalize", s.handlePollFinalize)
	s.mux.HandleFunc("GET /api/sync/changes", s.handleSyncChanges)
	s.mux.HandleFunc("GET /api/sync/key-envelope", s.handleContentKeyEnvelope)
	s.mux.HandleFunc("PUT /api/sync/key-envelope", s.handleContentKeyEnvelope)
	s.mux.HandleFunc("GET /api/sync/device-approvals", s.handleDeviceApprovals)
	s.mux.HandleFunc("POST /api/sync/device-approvals", s.handleDeviceApprovals)
	s.mux.HandleFunc("GET /api/sync/device-approvals/{id}", s.handleDeviceApprovalStatus)
	s.mux.HandleFunc("DELETE /api/sync/device-approvals/{id}", s.handleDeviceApprovalCancel)
	s.mux.HandleFunc("POST /api/sync/device-approvals/{id}/approve", s.handleDeviceApprovalApprove)
	s.mux.HandleFunc("POST /api/sync/device-approvals/{id}/reject", s.handleDeviceApprovalReject)
	s.mux.HandleFunc("POST /api/sync/device-approvals/{id}/consume", s.handleDeviceApprovalConsume)
	s.mux.HandleFunc("PUT /api/sync/objects/{collection}/{id}", s.handleSyncObject)
	s.mux.HandleFunc("DELETE /api/sync/objects/{collection}/{id}", s.handleSyncObject)
	s.mux.HandleFunc("GET /api/sync/events", s.handleSyncEvents)
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
	defer cancel()
	if err := s.db.PingContext(ctx); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status": "ok", "service": "daylink-api", "version": "0.5.0", "time": time.Now().UTC(),
	})
}

func decodeJSON(r *http.Request, destination any) error {
	if !strings.HasPrefix(strings.ToLower(r.Header.Get("Content-Type")), "application/json") {
		return errors.New("Content-Type must be application/json")
	}
	decoder := json.NewDecoder(io.LimitReader(r.Body, maxJSONBody))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(destination); err != nil {
		return fmt.Errorf("invalid JSON: %w", err)
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return errors.New("request body must contain one JSON value")
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, errorEnvelope{Error: apiError{Code: code, Message: message}})
}

func (s *Server) requireSameOrigin(w http.ResponseWriter, r *http.Request) bool {
	origin := strings.TrimRight(r.Header.Get("Origin"), "/")
	if origin == "" || subtle.ConstantTimeCompare([]byte(origin), []byte(s.cfg.PublicOrigin)) != 1 {
		writeError(w, http.StatusForbidden, "cross_origin_forbidden", "请求来源无效")
		return false
	}
	if fetchSite := r.Header.Get("Sec-Fetch-Site"); fetchSite != "" && fetchSite != "same-origin" {
		writeError(w, http.StatusForbidden, "cross_origin_forbidden", "请求来源无效")
		return false
	}
	return true
}

func (s *Server) setPrivateCookie(w http.ResponseWriter, r *http.Request, name, value string, ttl time.Duration) {
	http.SetCookie(w, &http.Cookie{
		Name: name, Value: value, Path: "/", HttpOnly: true,
		Secure: s.cookieSecure(r), SameSite: http.SameSiteStrictMode,
		MaxAge: int(ttl.Seconds()), Expires: time.Now().Add(ttl),
	})
}

func (s *Server) clearCookie(w http.ResponseWriter, r *http.Request, name string) {
	http.SetCookie(w, &http.Cookie{
		Name: name, Value: "", Path: "/", HttpOnly: true,
		Secure: s.cookieSecure(r), SameSite: http.SameSiteStrictMode,
		MaxAge: -1, Expires: time.Unix(1, 0),
	})
}

func (s *Server) cookieSecure(r *http.Request) bool {
	return r.TLS != nil || strings.HasPrefix(s.cfg.PublicOrigin, "https://")
}

func (s *Server) requireAdmin(w http.ResponseWriter, r *http.Request) (*adminIdentity, bool) {
	cookie, err := r.Cookie(adminCookie)
	if err != nil || len(cookie.Value) < 32 || len(cookie.Value) > 256 {
		writeError(w, http.StatusUnauthorized, "unauthorized", "请先登录后台")
		return nil, false
	}
	tokenHash := security.SHA256(cookie.Value)
	uaHash := security.PrivateHash(s.cfg.AuthMasterKey, "user-agent", r.UserAgent())
	var identity adminIdentity
	err = s.db.QueryRowContext(r.Context(), `SELECT a.id, a.username
      FROM admin_sessions s JOIN admin_accounts a ON a.id = s.admin_id
      WHERE s.token_hash = ? AND s.user_agent_hash = ? AND s.revoked_at IS NULL
        AND s.expires_at > UTC_TIMESTAMP(6) AND a.status = 'active' LIMIT 1`, tokenHash, uaHash).
		Scan(&identity.ID, &identity.Username)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthorized", "后台登录已失效")
		return nil, false
	}
	identity.Actor = "admin:" + identity.ID
	return &identity, true
}

func (s *Server) requireApp(w http.ResponseWriter, r *http.Request) (*appIdentity, bool) {
	authorization := r.Header.Get("Authorization")
	if !strings.HasPrefix(authorization, "Bearer dlka_") || len(authorization) > 300 {
		writeError(w, http.StatusUnauthorized, "unauthorized", "App 登录已失效")
		return nil, false
	}
	hash := security.SHA256(strings.TrimPrefix(authorization, "Bearer "))
	var identity appIdentity
	err := s.db.QueryRowContext(r.Context(), `SELECT a.id, s.id, a.username, s.device_name, s.e2ee_trusted, a.password_change_required
      FROM app_sessions s JOIN app_accounts a ON a.id = s.account_id
      WHERE s.access_token_hash = ? AND s.revoked_at IS NULL AND s.access_expires_at > UTC_TIMESTAMP(6)
        AND a.status = 'active' LIMIT 1`, hash).
		Scan(&identity.AccountID, &identity.SessionID, &identity.Username, &identity.DeviceName, &identity.E2EETrusted, &identity.PasswordChangeRequired)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "unauthorized", "App 登录已失效")
		return nil, false
	}
	_, _ = s.db.ExecContext(r.Context(),
		`UPDATE app_sessions SET last_seen_at = UTC_TIMESTAMP(6)
         WHERE id = ? AND revoked_at IS NULL
           AND last_seen_at < DATE_SUB(UTC_TIMESTAMP(6), INTERVAL 30 SECOND)`,
		identity.SessionID,
	)
	return &identity, true
}

func (s *Server) newAdminSession(ctx context.Context, adminID, userAgent string) (string, error) {
	token, err := security.RandomToken("dla_")
	if err != nil {
		return "", err
	}
	id, err := security.RandomID()
	if err != nil {
		return "", err
	}
	_, err = s.db.ExecContext(ctx, `INSERT INTO admin_sessions
      (id, admin_id, token_hash, user_agent_hash, expires_at, last_seen_at)
      VALUES (?, ?, ?, ?, ?, ?)`, id, adminID, security.SHA256(token),
		security.PrivateHash(s.cfg.AuthMasterKey, "user-agent", userAgent),
		time.Now().UTC().Add(adminSessionTTL), time.Now().UTC())
	return token, err
}

type appTokenPair struct {
	AccessToken      string    `json:"accessToken"`
	AccessExpiresAt  time.Time `json:"accessExpiresAt"`
	RefreshToken     string    `json:"refreshToken"`
	RefreshExpiresAt time.Time `json:"refreshExpiresAt"`
}

func (s *Server) newAppSession(ctx context.Context, accountID, deviceName string) (appTokenPair, error) {
	return s.newAppSessionWith(ctx, s.db, accountID, deviceName, false)
}

func (s *Server) newAppSessionWith(ctx context.Context, execer contextExecer, accountID, deviceName string, e2eeTrusted bool) (appTokenPair, error) {
	pair, err := newAppTokenPair()
	if err != nil {
		return appTokenPair{}, err
	}
	id, err := security.RandomID()
	if err != nil {
		return appTokenPair{}, err
	}
	now := time.Now().UTC()
	_, err = execer.ExecContext(ctx, `INSERT INTO app_sessions
		(id, account_id, access_token_hash, refresh_token_hash, device_name, e2ee_trusted,
		 access_expires_at, refresh_expires_at, last_seen_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`, id, accountID, security.SHA256(pair.AccessToken),
		security.SHA256(pair.RefreshToken), deviceName, e2eeTrusted, pair.AccessExpiresAt, pair.RefreshExpiresAt, now)
	return pair, err
}

func newAppTokenPair() (appTokenPair, error) {
	access, err := security.RandomToken("dlka_")
	if err != nil {
		return appTokenPair{}, err
	}
	refresh, err := security.RandomToken("dlkr_")
	if err != nil {
		return appTokenPair{}, err
	}
	now := time.Now().UTC()
	pair := appTokenPair{access, now.Add(appAccessTTL), refresh, now.Add(appRefreshTTL)}
	return pair, nil
}

func (s *Server) consumeRateLimit(ctx context.Context, r *http.Request, action, identity string, maximum int) (time.Duration, error) {
	key := security.PrivateHash(s.cfg.AuthMasterKey, "rate-limit:"+action, s.clientAddress(r)+"\x00"+strings.ToLower(identity))
	now := time.Now().UTC()
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer func() { _ = tx.Rollback() }()
	var started time.Time
	var attempts int
	var blocked sql.NullTime
	err = tx.QueryRowContext(ctx, `SELECT window_started_at, attempts, blocked_until
      FROM auth_rate_limits WHERE bucket_key = ? FOR UPDATE`, key).Scan(&started, &attempts, &blocked)
	if errors.Is(err, sql.ErrNoRows) {
		_, err = tx.ExecContext(ctx, `INSERT INTO auth_rate_limits
        (bucket_key, action, window_started_at, attempts) VALUES (?, ?, ?, 1)`, key, action, now)
		if err != nil {
			return 0, err
		}
		return 0, tx.Commit()
	}
	if err != nil {
		return 0, err
	}
	if blocked.Valid && blocked.Time.After(now) {
		return time.Until(blocked.Time), nil
	}
	if now.Sub(started) >= rateLimitWindow {
		started, attempts, blocked = now, 1, sql.NullTime{}
	} else {
		attempts++
		if attempts > maximum {
			blocked = sql.NullTime{Time: now.Add(rateLimitBlock), Valid: true}
		}
	}
	_, err = tx.ExecContext(ctx, `UPDATE auth_rate_limits SET window_started_at = ?, attempts = ?,
      blocked_until = ?, updated_at = ? WHERE bucket_key = ?`, started, attempts, nullableTime(blocked), now, key)
	if err != nil {
		return 0, err
	}
	if err := tx.Commit(); err != nil {
		return 0, err
	}
	if blocked.Valid {
		return time.Until(blocked.Time), nil
	}
	return 0, nil
}

func nullableTime(value sql.NullTime) any {
	if value.Valid {
		return value.Time
	}
	return nil
}

func (s *Server) clientAddress(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return "unknown"
	}
	remoteIP := net.ParseIP(host)
	trusted := false
	for _, network := range s.trustedProxies {
		if remoteIP != nil && network.Contains(remoteIP) {
			trusted = true
			break
		}
	}
	if trusted {
		forwarded := strings.Split(r.Header.Get("X-Forwarded-For"), ",")
		for index := len(forwarded) - 1; index >= 0; index-- {
			candidate := strings.TrimSpace(forwarded[index])
			if net.ParseIP(candidate) != nil {
				return candidate
			}
		}
	}
	return host
}

func (s *Server) audit(ctx context.Context, actor, action, targetType, targetID, outcome, risk string) {
	id, err := security.RandomID()
	if err != nil {
		return
	}
	if targetID == "" {
		_, _ = s.db.ExecContext(ctx, `INSERT INTO audit_events
        (id, actor, action, target_type, target_id, outcome, risk, metadata_json)
        VALUES (?, ?, ?, ?, NULL, ?, ?, JSON_OBJECT())`, id, actor, action, targetType, outcome, risk)
		return
	}
	_, _ = s.db.ExecContext(ctx, `INSERT INTO audit_events
      (id, actor, action, target_type, target_id, outcome, risk, metadata_json)
      VALUES (?, ?, ?, ?, ?, ?, ?, JSON_OBJECT())`, id, actor, action, targetType, targetID, outcome, risk)
}

func (s *Server) writeAsset(id string, content []byte) (string, error) {
	s.assetMutex.Lock()
	defer s.assetMutex.Unlock()
	if err := os.MkdirAll(s.cfg.AssetDirectory, 0o700); err != nil {
		return "", err
	}
	objectKey := id + ".png"
	path := filepath.Join(s.cfg.AssetDirectory, objectKey)
	if err := os.WriteFile(path, content, 0o600); err != nil {
		return "", err
	}
	return objectKey, nil
}

func (s *Server) securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		w.Header().Set("Permissions-Policy", "camera=(), microphone=(), geolocation=()")
		w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'; base-uri 'none'")
		next.ServeHTTP(w, r)
	})
}

func (s *Server) recoverPanic(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if recovered := recover(); recovered != nil {
				s.logger.Error("request panic", "method", r.Method, "path", r.URL.Path)
				writeError(w, http.StatusInternalServerError, "internal_error", "服务暂时不可用")
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func validatePublicHTTPSBaseURL(raw string) (string, error) {
	parsed, err := url.Parse(strings.TrimRight(strings.TrimSpace(raw), "/"))
	if err != nil || parsed.Scheme != "https" || parsed.Hostname() == "" || parsed.User != nil || parsed.RawQuery != "" || parsed.Fragment != "" {
		return "", errors.New("API 地址必须是无凭据、无查询参数的公网 HTTPS 地址")
	}
	host := strings.ToLower(parsed.Hostname())
	if host == "localhost" || strings.HasSuffix(host, ".localhost") || strings.HasSuffix(host, ".local") || net.ParseIP(host) != nil {
		return "", errors.New("API 地址不能使用本地或 IP 地址")
	}
	return parsed.String(), nil
}
