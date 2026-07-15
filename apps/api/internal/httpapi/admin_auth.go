package httpapi

import (
	"context"
	"crypto/subtle"
	"database/sql"
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

type adminAccountRecord struct {
	ID                  string
	Username            string
	PasswordAlgorithm   string
	PasswordHash        string
	PasswordSalt        string
	PasswordIterations  int
	TOTPCiphertext      []byte
	TOTPNonce           []byte
	TOTPLastCounter     sql.NullInt64
	Status              string
	EnrollmentTokenHash sql.NullString
	EnrollmentExpiresAt sql.NullTime
	FailedLoginCount    int
	LockedUntil         sql.NullTime
}

func (a adminAccountRecord) passwordDigest() security.PasswordDigest {
	return security.PasswordDigest{Algorithm: a.PasswordAlgorithm, Hash: a.PasswordHash, Salt: a.PasswordSalt, Iterations: a.PasswordIterations}
}

func (s *Server) handleAdminBootstrap(w http.ResponseWriter, r *http.Request) {
	if identity, ok := s.optionalAdmin(r); ok {
		writeJSON(w, http.StatusOK, map[string]any{"state": "authenticated", "username": identity.Username})
		return
	}
	var status string
	var expires sql.NullTime
	err := s.db.QueryRowContext(r.Context(), "SELECT status, enrollment_expires_at FROM admin_accounts LIMIT 1").Scan(&status, &expires)
	if errors.Is(err, sql.ErrNoRows) {
		writeJSON(w, http.StatusOK, map[string]any{"state": "uninitialized"})
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if status == "pending" && (!expires.Valid || expires.Time.Before(time.Now().UTC())) {
		_, _ = s.db.ExecContext(r.Context(), "DELETE FROM admin_accounts WHERE status = 'pending' AND enrollment_expires_at <= UTC_TIMESTAMP(6)")
		writeJSON(w, http.StatusOK, map[string]any{"state": "uninitialized"})
		return
	}
	if status == "pending" {
		if account, ok := s.pendingEnrollment(r); ok {
			writeJSON(w, http.StatusOK, map[string]any{"state": "enrollment", "username": account.Username})
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"state": "pending"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"state": "login"})
}

func (s *Server) handleAdminSetup(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "admin_setup", "singleton", 5); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		w.Header().Set("Retry-After", strconv.FormatInt(max(1, int64(retry.Seconds())), 10))
		writeError(w, http.StatusTooManyRequests, "rate_limited", "尝试次数过多，请稍后重试")
		return
	}
	var input struct {
		Username        string `json:"username"`
		Password        string `json:"password"`
		ConfirmPassword string `json:"confirmPassword"`
		SetupToken      string `json:"setupToken,omitempty"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if s.cfg.AdminSetupToken != "" {
		expected := security.PrivateHash(s.cfg.AuthMasterKey, "admin-setup-token", s.cfg.AdminSetupToken)
		provided := security.PrivateHash(s.cfg.AuthMasterKey, "admin-setup-token", input.SetupToken)
		if subtle.ConstantTimeCompare([]byte(expected), []byte(provided)) != 1 {
			s.audit(r.Context(), "system:first-admin-setup", "admin.enrollment.authorize", "admin_account", "", "denied", "critical")
			writeError(w, http.StatusForbidden, "setup_forbidden", "部署初始化口令不正确")
			return
		}
	}
	username, err := security.ValidateUsername(input.Username)
	if err != nil || input.Password != input.ConfirmPassword {
		if err == nil {
			err = errors.New("两次输入的密码不一致")
		}
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	digest, err := security.HashPassword(input.Password, "admin", s.cfg.AuthMasterKey)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	secret, err := security.NewTOTPSecret()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "setup_failed", "暂时无法创建管理员")
		return
	}
	id, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "setup_failed", "暂时无法创建管理员")
		return
	}
	ciphertext, nonce, err := security.Encrypt(s.cfg.AuthMasterKey, "admin-totp:"+id, []byte(secret))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "setup_failed", "暂时无法创建管理员")
		return
	}
	enrollmentToken, err := security.RandomToken("dle_")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "setup_failed", "暂时无法创建管理员")
		return
	}
	now := time.Now().UTC()
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	if _, err := tx.ExecContext(r.Context(), "DELETE FROM admin_accounts WHERE status = 'pending' AND enrollment_expires_at <= UTC_TIMESTAMP(6)"); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	var count int
	if err := tx.QueryRowContext(r.Context(), "SELECT COUNT(*) FROM admin_accounts").Scan(&count); err != nil || count != 0 {
		writeError(w, http.StatusConflict, "setup_unavailable", "后台已初始化或正在初始化")
		return
	}
	_, err = tx.ExecContext(r.Context(), `INSERT INTO admin_accounts
      (id, singleton_key, username, username_canonical, password_algorithm, password_hash,
       password_salt, password_iterations, totp_secret_ciphertext, totp_secret_nonce,
       status, enrollment_token_hash, enrollment_expires_at, password_changed_at)
      VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)`, id, username,
		strings.ToLower(username), digest.Algorithm, digest.Hash, digest.Salt, digest.Iterations,
		ciphertext, nonce, security.SHA256(enrollmentToken), now.Add(enrollmentTTL), now)
	if err != nil {
		writeError(w, http.StatusConflict, "setup_unavailable", "后台已初始化或正在初始化")
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	s.audit(r.Context(), "system:first-admin-setup", "admin.enrollment.started", "admin_account", id, "allowed", "critical")
	s.setPrivateCookie(w, r, enrollmentCookie, enrollmentToken, enrollmentTTL)
	writeJSON(w, http.StatusCreated, map[string]any{"next": "/admin/setup/2fa"})
}

func (s *Server) handleAdminSetupCancel(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	account, ok := s.pendingEnrollment(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "enrollment_expired", "初始化会话已失效")
		return
	}
	_, _ = s.db.ExecContext(r.Context(), "DELETE FROM admin_accounts WHERE id = ? AND status = 'pending'", account.ID)
	s.clearCookie(w, r, enrollmentCookie)
	s.audit(r.Context(), "system:first-admin-setup", "admin.enrollment.cancelled", "admin_account", account.ID, "allowed", "critical")
	writeJSON(w, http.StatusOK, map[string]any{"next": "/admin"})
}

func (s *Server) handleAdminEnrollment(w http.ResponseWriter, r *http.Request) {
	account, ok := s.pendingEnrollment(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "enrollment_expired", "初始化会话已失效")
		return
	}
	plaintext, err := security.Decrypt(s.cfg.AuthMasterKey, "admin-totp:"+account.ID, account.TOTPCiphertext, account.TOTPNonce)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "enrollment_failed", "暂时无法读取绑定信息")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"username": account.Username, "secret": string(plaintext),
		"uri": security.TOTPUri(account.Username, string(plaintext)), "expiresAt": account.EnrollmentExpiresAt.Time,
	})
}

func (s *Server) handleAdminEnrollmentVerify(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	var input struct {
		Code string `json:"code"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "totp_enrollment", "verify", 8); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "尝试次数过多，请稍后重试")
		return
	}
	account, ok := s.pendingEnrollment(r)
	if !ok {
		writeError(w, http.StatusUnauthorized, "enrollment_expired", "初始化会话已失效，请重新开始")
		return
	}
	plaintext, err := security.Decrypt(s.cfg.AuthMasterKey, "admin-totp:"+account.ID, account.TOTPCiphertext, account.TOTPNonce)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "verification_failed", "验证失败")
		return
	}
	counter, ok := security.VerifyTOTP(string(plaintext), strings.TrimSpace(input.Code), nil, time.Now().UTC())
	if !ok {
		s.audit(r.Context(), "system:first-admin-setup", "admin.enrollment.verify", "admin_account", account.ID, "denied", "critical")
		writeError(w, http.StatusUnauthorized, "invalid_code", "验证码不正确或已使用")
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE admin_accounts SET status = 'active', totp_last_counter = ?,
      enrollment_token_hash = NULL, enrollment_expires_at = NULL, activated_at = UTC_TIMESTAMP(6)
      WHERE id = ? AND status = 'pending'`, counter, account.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if changed, _ := result.RowsAffected(); changed != 1 {
		writeError(w, http.StatusConflict, "enrollment_conflict", "初始化状态已变化")
		return
	}
	session, err := s.newAdminSession(r.Context(), account.ID, r.UserAgent())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "session_failed", "暂时无法建立后台会话")
		return
	}
	s.setPrivateCookie(w, r, adminCookie, session, adminSessionTTL)
	s.clearCookie(w, r, enrollmentCookie)
	s.audit(r.Context(), "admin:"+account.ID, "admin.enrollment.completed", "admin_account", account.ID, "allowed", "critical")
	writeJSON(w, http.StatusOK, map[string]any{"next": "/admin"})
}

func (s *Server) handleAdminLogin(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	var input struct {
		Username string `json:"username"`
		Password string `json:"password"`
		Code     string `json:"code"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "admin_login", input.Username, 10); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "尝试次数过多，请稍后重试")
		return
	}
	account, err := s.adminByUsername(r.Context(), input.Username)
	if err != nil {
		_, _ = security.HashPassword("Dummy!Password123", "admin", s.cfg.AuthMasterKey)
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "账号、密码或验证码不正确")
		return
	}
	locked := account.LockedUntil.Valid && account.LockedUntil.Time.After(time.Now().UTC())
	validPassword := security.VerifyPassword(input.Password, "admin", account.passwordDigest(), s.cfg.AuthMasterKey)
	var counter int64
	validCode := false
	if account.Status == "active" && validPassword && !locked {
		secret, decryptErr := security.Decrypt(s.cfg.AuthMasterKey, "admin-totp:"+account.ID, account.TOTPCiphertext, account.TOTPNonce)
		if decryptErr == nil {
			var last *int64
			if account.TOTPLastCounter.Valid {
				last = &account.TOTPLastCounter.Int64
			}
			counter, validCode = security.VerifyTOTP(string(secret), input.Code, last, time.Now().UTC())
		}
	}
	if account.Status != "active" || !validPassword || !validCode || locked {
		_, _ = s.db.ExecContext(r.Context(), `UPDATE admin_accounts SET failed_login_count = failed_login_count + 1,
        locked_until = CASE WHEN failed_login_count + 1 >= 5 THEN DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 15 MINUTE) ELSE locked_until END
        WHERE id = ?`, account.ID)
		s.audit(r.Context(), "admin:"+account.ID, "admin.login", "admin_session", account.ID, "denied", "high")
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "账号、密码或验证码不正确")
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE admin_accounts SET totp_last_counter = ?, failed_login_count = 0,
      locked_until = NULL, last_login_at = UTC_TIMESTAMP(6) WHERE id = ? AND status = 'active'
      AND (totp_last_counter IS NULL OR totp_last_counter < ?)`, counter, account.ID, counter)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "login_failed", "登录失败，请稍后重试")
		return
	}
	if changed, _ := result.RowsAffected(); changed != 1 {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "账号、密码或验证码不正确")
		return
	}
	token, err := s.newAdminSession(r.Context(), account.ID, r.UserAgent())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "login_failed", "登录失败，请稍后重试")
		return
	}
	s.setPrivateCookie(w, r, adminCookie, token, adminSessionTTL)
	s.audit(r.Context(), "admin:"+account.ID, "admin.login", "admin_session", "", "allowed", "high")
	writeJSON(w, http.StatusOK, map[string]any{"next": "/admin"})
}

func (s *Server) handleAdminLogout(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	if cookie, err := r.Cookie(adminCookie); err == nil {
		_, _ = s.db.ExecContext(r.Context(), "UPDATE admin_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE token_hash = ?", security.SHA256(cookie.Value))
	}
	s.clearCookie(w, r, adminCookie)
	writeJSON(w, http.StatusOK, map[string]any{"loggedOut": true})
}

func (s *Server) handleAdminPassword(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	var input struct {
		CurrentPassword string `json:"currentPassword"`
		CurrentCode     string `json:"currentCode"`
		NewPassword     string `json:"newPassword"`
		ConfirmPassword string `json:"confirmPassword"`
	}
	if err := decodeJSON(r, &input); err != nil || input.NewPassword != input.ConfirmPassword {
		writeError(w, http.StatusBadRequest, "invalid_request", "两次输入的新密码不一致")
		return
	}
	account, err := s.adminByID(r.Context(), identity.ID)
	if err != nil || !security.VerifyPassword(input.CurrentPassword, "admin", account.passwordDigest(), s.cfg.AuthMasterKey) {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "当前密码或验证码不正确")
		return
	}
	secret, err := security.Decrypt(s.cfg.AuthMasterKey, "admin-totp:"+account.ID, account.TOTPCiphertext, account.TOTPNonce)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "verification_failed", "暂时无法验证身份")
		return
	}
	var last *int64
	if account.TOTPLastCounter.Valid {
		last = &account.TOTPLastCounter.Int64
	}
	counter, valid := security.VerifyTOTP(string(secret), input.CurrentCode, last, time.Now().UTC())
	if !valid || input.CurrentPassword == input.NewPassword {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "当前密码或验证码不正确")
		return
	}
	digest, err := security.HashPassword(input.NewPassword, "admin", s.cfg.AuthMasterKey)
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
	result, err := tx.ExecContext(r.Context(), `UPDATE admin_accounts SET password_algorithm = ?, password_hash = ?,
      password_salt = ?, password_iterations = ?, totp_last_counter = ?, password_changed_at = UTC_TIMESTAMP(6)
		WHERE id = ? AND (totp_last_counter IS NULL OR totp_last_counter < ?)`,
		digest.Algorithm, digest.Hash, digest.Salt, digest.Iterations, counter, account.ID, counter)
	if err == nil {
		if changed, rowsErr := result.RowsAffected(); rowsErr != nil || changed != 1 {
			err = errors.New("TOTP code was already used")
		}
	}
	if err == nil {
		_, err = tx.ExecContext(r.Context(), "UPDATE admin_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE admin_id = ? AND revoked_at IS NULL", account.ID)
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "password_change_failed", "修改密码失败")
		return
	}
	s.clearCookie(w, r, adminCookie)
	s.audit(r.Context(), identity.Actor, "admin.password.change", "admin_account", account.ID, "allowed", "critical")
	writeJSON(w, http.StatusOK, map[string]any{"reauthenticate": true})
}

func (s *Server) handleAdminTOTP(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	var raw map[string]jsonRaw
	if err := decodeJSON(r, &raw); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	action := rawString(raw["action"])
	if action == "start" {
		s.startTOTPRebind(w, r, identity, rawString(raw["currentPassword"]), rawString(raw["currentCode"]))
		return
	}
	if action == "verify" {
		s.verifyTOTPRebind(w, r, identity, rawString(raw["code"]))
		return
	}
	writeError(w, http.StatusBadRequest, "invalid_request", "不支持的操作")
}

type jsonRaw = []byte

func rawString(raw jsonRaw) string {
	if len(raw) == 0 {
		return ""
	}
	var value string
	_ = json.Unmarshal(raw, &value)
	return value
}

func (s *Server) startTOTPRebind(w http.ResponseWriter, r *http.Request, identity *adminIdentity, password, code string) {
	account, err := s.adminByID(r.Context(), identity.ID)
	if err != nil || !security.VerifyPassword(password, "admin", account.passwordDigest(), s.cfg.AuthMasterKey) {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "当前密码或验证码不正确")
		return
	}
	oldSecret, err := security.Decrypt(s.cfg.AuthMasterKey, "admin-totp:"+account.ID, account.TOTPCiphertext, account.TOTPNonce)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "verification_failed", "暂时无法验证身份")
		return
	}
	var last *int64
	if account.TOTPLastCounter.Valid {
		last = &account.TOTPLastCounter.Int64
	}
	counter, ok := security.VerifyTOTP(string(oldSecret), code, last, time.Now().UTC())
	if !ok {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "当前密码或验证码不正确")
		return
	}
	newSecret, err := security.NewTOTPSecret()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "totp_rebind_failed", "暂时无法重新绑定")
		return
	}
	rebindID, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "totp_rebind_failed", "暂时无法重新绑定")
		return
	}
	token, err := security.RandomToken("dlb_")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "totp_rebind_failed", "暂时无法重新绑定")
		return
	}
	ciphertext, nonce, err := security.Encrypt(s.cfg.AuthMasterKey, "admin-totp-rebind:"+rebindID, []byte(newSecret))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "totp_rebind_failed", "暂时无法重新绑定")
		return
	}
	expires := time.Now().UTC().Add(enrollmentTTL)
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	_, err = tx.ExecContext(r.Context(), "DELETE FROM admin_totp_rebindings WHERE admin_id = ?", account.ID)
	if err == nil {
		_, err = tx.ExecContext(r.Context(), `INSERT INTO admin_totp_rebindings
      (id, admin_id, token_hash, secret_ciphertext, secret_nonce, expires_at) VALUES (?, ?, ?, ?, ?, ?)`,
			rebindID, account.ID, security.SHA256(token), ciphertext, nonce, expires)
	}
	if err == nil {
		var result sql.Result
		result, err = tx.ExecContext(r.Context(), `UPDATE admin_accounts SET totp_last_counter = ?
			WHERE id = ? AND (totp_last_counter IS NULL OR totp_last_counter < ?)`, counter, account.ID, counter)
		if err == nil {
			if changed, rowsErr := result.RowsAffected(); rowsErr != nil || changed != 1 {
				err = errors.New("TOTP code was already used")
			}
		}
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "totp_rebind_failed", "暂时无法重新绑定")
		return
	}
	s.setPrivateCookie(w, r, rebindCookie, token, enrollmentTTL)
	writeJSON(w, http.StatusOK, map[string]any{"username": account.Username, "secret": newSecret, "uri": security.TOTPUri(account.Username, newSecret), "expiresAt": expires})
}

func (s *Server) verifyTOTPRebind(w http.ResponseWriter, r *http.Request, identity *adminIdentity, code string) {
	cookie, err := r.Cookie(rebindCookie)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "rebind_expired", "重新绑定会话已失效")
		return
	}
	var id string
	var ciphertext, nonce []byte
	err = s.db.QueryRowContext(r.Context(), `SELECT id, secret_ciphertext, secret_nonce FROM admin_totp_rebindings
      WHERE admin_id = ? AND token_hash = ? AND expires_at > UTC_TIMESTAMP(6)`, identity.ID, security.SHA256(cookie.Value)).
		Scan(&id, &ciphertext, &nonce)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "rebind_expired", "重新绑定会话已失效")
		return
	}
	secret, err := security.Decrypt(s.cfg.AuthMasterKey, "admin-totp-rebind:"+id, ciphertext, nonce)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "totp_rebind_failed", "暂时无法重新绑定")
		return
	}
	counter, ok := security.VerifyTOTP(string(secret), code, nil, time.Now().UTC())
	if !ok {
		writeError(w, http.StatusUnauthorized, "invalid_code", "验证码不正确或已使用")
		return
	}
	newCiphertext, newNonce, err := security.Encrypt(s.cfg.AuthMasterKey, "admin-totp:"+identity.ID, secret)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "totp_rebind_failed", "暂时无法重新绑定")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	_, err = tx.ExecContext(r.Context(), `UPDATE admin_accounts SET totp_secret_ciphertext = ?, totp_secret_nonce = ?,
      totp_last_counter = ? WHERE id = ?`, newCiphertext, newNonce, counter, identity.ID)
	if err == nil {
		_, err = tx.ExecContext(r.Context(), "DELETE FROM admin_totp_rebindings WHERE id = ?", id)
	}
	if err == nil {
		_, err = tx.ExecContext(r.Context(), "UPDATE admin_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE admin_id = ?", identity.ID)
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "totp_rebind_failed", "暂时无法重新绑定")
		return
	}
	s.clearCookie(w, r, rebindCookie)
	s.clearCookie(w, r, adminCookie)
	s.audit(r.Context(), identity.Actor, "admin.totp.rebind", "admin_account", identity.ID, "allowed", "critical")
	writeJSON(w, http.StatusOK, map[string]any{"reauthenticate": true})
}

func (s *Server) handleAdminTOTPCancel(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	_, _ = s.db.ExecContext(r.Context(), "DELETE FROM admin_totp_rebindings WHERE admin_id = ?", identity.ID)
	s.clearCookie(w, r, rebindCookie)
	writeJSON(w, http.StatusOK, map[string]any{"cancelled": true})
}

func (s *Server) optionalAdmin(r *http.Request) (*adminIdentity, bool) {
	cookie, err := r.Cookie(adminCookie)
	if err != nil {
		return nil, false
	}
	var identity adminIdentity
	err = s.db.QueryRowContext(r.Context(), `SELECT a.id, a.username FROM admin_sessions s
      JOIN admin_accounts a ON a.id = s.admin_id WHERE s.token_hash = ? AND s.user_agent_hash = ?
      AND s.revoked_at IS NULL AND s.expires_at > UTC_TIMESTAMP(6) AND a.status = 'active' LIMIT 1`,
		security.SHA256(cookie.Value), security.PrivateHash(s.cfg.AuthMasterKey, "user-agent", r.UserAgent())).
		Scan(&identity.ID, &identity.Username)
	if err != nil {
		return nil, false
	}
	identity.Actor = "admin:" + identity.ID
	return &identity, true
}

func (s *Server) pendingEnrollment(r *http.Request) (adminAccountRecord, bool) {
	cookie, err := r.Cookie(enrollmentCookie)
	if err != nil {
		return adminAccountRecord{}, false
	}
	account, err := s.scanAdmin(s.db.QueryRowContext(r.Context(), `SELECT id, username, password_algorithm,
      password_hash, password_salt, password_iterations, totp_secret_ciphertext, totp_secret_nonce,
      totp_last_counter, status, enrollment_token_hash, enrollment_expires_at, failed_login_count, locked_until
      FROM admin_accounts WHERE status = 'pending' AND enrollment_token_hash = ?
      AND enrollment_expires_at > UTC_TIMESTAMP(6) LIMIT 1`, security.SHA256(cookie.Value)))
	return account, err == nil
}

func (s *Server) adminByUsername(ctx context.Context, username string) (adminAccountRecord, error) {
	return s.scanAdmin(s.db.QueryRowContext(ctx, `SELECT id, username, password_algorithm, password_hash,
      password_salt, password_iterations, totp_secret_ciphertext, totp_secret_nonce, totp_last_counter,
      status, enrollment_token_hash, enrollment_expires_at, failed_login_count, locked_until
      FROM admin_accounts WHERE username_canonical = ? LIMIT 1`, strings.ToLower(strings.TrimSpace(username))))
}

func (s *Server) adminByID(ctx context.Context, id string) (adminAccountRecord, error) {
	return s.scanAdmin(s.db.QueryRowContext(ctx, `SELECT id, username, password_algorithm, password_hash,
      password_salt, password_iterations, totp_secret_ciphertext, totp_secret_nonce, totp_last_counter,
      status, enrollment_token_hash, enrollment_expires_at, failed_login_count, locked_until
      FROM admin_accounts WHERE id = ? LIMIT 1`, id))
}

type rowScanner interface{ Scan(...any) error }

func (s *Server) scanAdmin(row rowScanner) (adminAccountRecord, error) {
	var account adminAccountRecord
	err := row.Scan(&account.ID, &account.Username, &account.PasswordAlgorithm, &account.PasswordHash,
		&account.PasswordSalt, &account.PasswordIterations, &account.TOTPCiphertext, &account.TOTPNonce,
		&account.TOTPLastCounter, &account.Status, &account.EnrollmentTokenHash, &account.EnrollmentExpiresAt,
		&account.FailedLoginCount, &account.LockedUntil)
	return account, err
}
