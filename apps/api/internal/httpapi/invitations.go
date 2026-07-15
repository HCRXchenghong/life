package httpapi

import (
	"crypto/subtle"
	"database/sql"
	"encoding/base32"
	"net/http"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

const maximumInvitationCodeLength = 32

func (s *Server) handleAdminAppInvitation(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "app_invitation_admin", identity.ID, 20); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "邀请创建过于频繁")
		return
	}

	var input struct {
		Validity string `json:"validity"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "邀请有效期无效")
		return
	}
	duration, ok := invitationDuration(input.Validity)
	if !ok {
		writeError(w, http.StatusBadRequest, "invalid_request", "邀请有效期无效")
		return
	}

	id, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "invitation_create_failed", "暂时无法创建邀请")
		return
	}
	token, err := security.RandomToken("dli_")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "invitation_create_failed", "暂时无法创建邀请")
		return
	}
	code, err := newInvitationCode()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "invitation_create_failed", "暂时无法创建邀请")
		return
	}
	expiresAt := time.Now().UTC().Add(duration)
	_, err = s.db.ExecContext(r.Context(), `INSERT INTO app_account_invitations
      (id, admin_id, token_hash, code_hash, expires_at) VALUES (?, ?, ?, ?, ?)`,
		id, identity.ID, security.SHA256(token), invitationCodeHash(s.cfg.AuthMasterKey, id, code), expiresAt)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "invitation_create_failed", "暂时无法创建邀请")
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	s.audit(r.Context(), identity.Actor, "app_invitation.create", "app_invitation", id, "allowed", "high")
	writeJSON(w, http.StatusCreated, map[string]any{"invitation": map[string]any{
		"path": "/invite/" + token, "code": code, "expiresAt": expiresAt,
	}})
}

func (s *Server) handleAppInvitation(w http.ResponseWriter, r *http.Request) {
	token := r.PathValue("token")
	if !validInvitationToken(token) {
		writeError(w, http.StatusNotFound, "invitation_unavailable", "邀请链接不可用")
		return
	}
	w.Header().Set("Cache-Control", "no-store")
	if r.Method == http.MethodGet {
		s.getAppInvitation(w, r, token)
		return
	}
	if !s.requireSameOrigin(w, r) {
		return
	}
	s.consumeAppInvitation(w, r, token)
}

func (s *Server) getAppInvitation(w http.ResponseWriter, r *http.Request, token string) {
	var expiresAt time.Time
	var usedAt, revokedAt sql.NullTime
	err := s.db.QueryRowContext(r.Context(), `SELECT expires_at, used_at, revoked_at
      FROM app_account_invitations WHERE token_hash = ? LIMIT 1`, security.SHA256(token)).
		Scan(&expiresAt, &usedAt, &revokedAt)
	if err != nil || usedAt.Valid || revokedAt.Valid || !expiresAt.After(time.Now().UTC()) {
		writeError(w, http.StatusNotFound, "invitation_unavailable", "邀请链接不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"valid": true, "expiresAt": expiresAt})
}

func (s *Server) consumeAppInvitation(w http.ResponseWriter, r *http.Request, token string) {
	tokenDigest := security.SHA256(token)
	if retry, err := s.consumeRateLimit(r.Context(), r, "app_invitation_consume", tokenDigest, 12); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "验证次数过多，请稍后重试")
		return
	}
	var input struct {
		Code            string `json:"code"`
		Username        string `json:"username"`
		Password        string `json:"password"`
		ConfirmPassword string `json:"confirmPassword"`
	}
	if err := decodeJSON(r, &input); err != nil || input.Password != input.ConfirmPassword || len(input.Code) == 0 || len(input.Code) > maximumInvitationCodeLength {
		writeError(w, http.StatusBadRequest, "invalid_request", "邀请信息无效")
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

	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var invitationID, wantedCodeHash string
	var expiresAt time.Time
	var usedAt, revokedAt sql.NullTime
	err = tx.QueryRowContext(r.Context(), `SELECT id, code_hash, expires_at, used_at, revoked_at
      FROM app_account_invitations WHERE token_hash = ? FOR UPDATE`, tokenDigest).
		Scan(&invitationID, &wantedCodeHash, &expiresAt, &usedAt, &revokedAt)
	providedCodeHash := invitationCodeHash(s.cfg.AuthMasterKey, invitationID, strings.ToUpper(strings.TrimSpace(input.Code)))
	if err != nil || usedAt.Valid || revokedAt.Valid || !expiresAt.After(time.Now().UTC()) ||
		subtle.ConstantTimeCompare([]byte(wantedCodeHash), []byte(providedCodeHash)) != 1 {
		writeError(w, http.StatusBadRequest, "invitation_unavailable", "邀请链接或邀请码无效")
		return
	}
	accountID, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "account_create_failed", "暂时无法创建账号")
		return
	}
	now := time.Now().UTC()
	_, err = tx.ExecContext(r.Context(), `INSERT INTO app_accounts
      (id, username, username_canonical, password_algorithm, password_hash, password_salt,
       password_iterations, password_change_required, status, password_changed_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, FALSE, 'active', ?)`, accountID, username, strings.ToLower(username),
		digest.Algorithm, digest.Hash, digest.Salt, digest.Iterations, now)
	if err != nil {
		writeError(w, http.StatusConflict, "username_unavailable", "该 App 账号已存在")
		return
	}
	result, err := tx.ExecContext(r.Context(), `UPDATE app_account_invitations
      SET used_at = ?, created_account_id = ? WHERE id = ? AND used_at IS NULL AND revoked_at IS NULL`, now, accountID, invitationID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "account_create_failed", "暂时无法创建账号")
		return
	}
	if changed, _ := result.RowsAffected(); changed != 1 {
		writeError(w, http.StatusConflict, "invitation_unavailable", "邀请链接不可用")
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "account_create_failed", "暂时无法创建账号")
		return
	}
	s.audit(r.Context(), "invitation:"+invitationID, "app_invitation.consume", "app_account", accountID, "allowed", "high")
	writeJSON(w, http.StatusCreated, map[string]any{"created": true, "username": username})
}

func invitationDuration(value string) (time.Duration, bool) {
	switch value {
	case "day":
		return 24 * time.Hour, true
	case "week":
		return 7 * 24 * time.Hour, true
	case "month":
		return 30 * 24 * time.Hour, true
	default:
		return 0, false
	}
}

func newInvitationCode() (string, error) {
	random, err := security.RandomBytes(6)
	if err != nil {
		return "", err
	}
	return base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(random), nil
}

func invitationCodeHash(masterKey []byte, invitationID, code string) string {
	return security.PrivateHash(masterKey, "app-invitation-code:"+invitationID, strings.ToUpper(strings.TrimSpace(code)))
}

func validInvitationToken(token string) bool {
	return strings.HasPrefix(token, "dli_") && len(token) >= 48 && len(token) <= 80 && !strings.ContainsAny(token, "/\\\r\n\x00")
}
