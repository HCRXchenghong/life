package httpapi

import (
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

type appAccountRecord struct {
	ID                     string
	Username               string
	PasswordAlgorithm      string
	PasswordHash           string
	PasswordSalt           string
	PasswordIterations     int
	PasswordChangeRequired bool
	Status                 string
	LockedUntil            sql.NullTime
}

type appDeviceSession struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	Current    bool      `json:"current"`
	LastSeenAt time.Time `json:"lastSeenAt"`
	CreatedAt  time.Time `json:"createdAt"`
}

func (a appAccountRecord) digest() security.PasswordDigest {
	return security.PasswordDigest{Algorithm: a.PasswordAlgorithm, Hash: a.PasswordHash, Salt: a.PasswordSalt, Iterations: a.PasswordIterations}
}

func (s *Server) handleAppLogin(w http.ResponseWriter, r *http.Request) {
	var input struct {
		Username   string `json:"username"`
		Password   string `json:"password"`
		DeviceName string `json:"deviceName"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	input.Username = strings.TrimSpace(input.Username)
	input.DeviceName = strings.TrimSpace(input.DeviceName)
	if input.DeviceName == "" {
		input.DeviceName = "Daylink device"
	}
	if len(input.DeviceName) > 80 || strings.ContainsAny(input.DeviceName, "\r\n\x00") {
		writeError(w, http.StatusBadRequest, "invalid_request", "设备名称无效")
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "app_login", input.Username, 10); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "尝试次数过多，请稍后重试")
		return
	}
	account, err := s.appAccountByUsername(r, input.Username)
	if err != nil {
		_, _ = security.HashPassword("Dummy!Password123", "app", s.cfg.AuthMasterKey)
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "账号或密码不正确")
		return
	}
	locked := account.LockedUntil.Valid && account.LockedUntil.Time.After(time.Now().UTC())
	valid := security.VerifyPassword(input.Password, "app", account.digest(), s.cfg.AuthMasterKey)
	if account.Status != "active" || locked || !valid {
		_, _ = s.db.ExecContext(r.Context(), `UPDATE app_accounts SET failed_login_count = failed_login_count + 1,
        locked_until = CASE WHEN failed_login_count + 1 >= 5 THEN DATE_ADD(UTC_TIMESTAMP(6), INTERVAL 15 MINUTE) ELSE locked_until END
        WHERE id = ?`, account.ID)
		s.audit(r.Context(), "app:"+account.ID, "app.login", "app_session", account.ID, "denied", "high")
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "账号或密码不正确")
		return
	}
	_, err = s.db.ExecContext(r.Context(), `UPDATE app_accounts SET failed_login_count = 0, locked_until = NULL,
      last_login_at = UTC_TIMESTAMP(6) WHERE id = ? AND status = 'active'`, account.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "login_failed", "登录失败，请稍后重试")
		return
	}
	pair, err := s.newAppSession(r.Context(), account.ID, input.DeviceName)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "login_failed", "登录失败，请稍后重试")
		return
	}
	s.audit(r.Context(), "app:"+account.ID, "app.login", "app_session", "", "allowed", "high")
	writeJSON(w, http.StatusOK, map[string]any{
		"account": map[string]any{"id": account.ID, "username": account.Username, "passwordChangeRequired": account.PasswordChangeRequired},
		"tokens":  pair,
	})
}

func (s *Server) handleAppRefresh(w http.ResponseWriter, r *http.Request) {
	var input struct {
		RefreshToken string `json:"refreshToken"`
	}
	if err := decodeJSON(r, &input); err != nil || !strings.HasPrefix(input.RefreshToken, "dlkr_") {
		writeError(w, http.StatusUnauthorized, "invalid_refresh_token", "登录已失效，请重新登录")
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "app_refresh", security.SHA256(input.RefreshToken), 20); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "鉴权服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "尝试次数过多，请稍后重试")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var sessionID, accountID, deviceName string
	var e2eeTrusted bool
	err = tx.QueryRowContext(r.Context(), `SELECT s.id, s.account_id, s.device_name, s.e2ee_trusted FROM app_sessions s
		JOIN app_accounts a ON a.id = s.account_id WHERE s.refresh_token_hash = ? AND s.revoked_at IS NULL
		AND s.refresh_expires_at > UTC_TIMESTAMP(6) AND a.status = 'active' FOR UPDATE`, security.SHA256(input.RefreshToken)).
		Scan(&sessionID, &accountID, &deviceName, &e2eeTrusted)
	if err != nil {
		writeError(w, http.StatusUnauthorized, "invalid_refresh_token", "登录已失效，请重新登录")
		return
	}
	if _, err = tx.ExecContext(r.Context(), "UPDATE app_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE id = ? AND revoked_at IS NULL", sessionID); err != nil {
		writeError(w, http.StatusInternalServerError, "refresh_failed", "刷新登录失败")
		return
	}
	pair, err := s.newAppSessionWith(r.Context(), tx, accountID, deviceName, e2eeTrusted)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "refresh_failed", "刷新登录失败")
		return
	}
	if err = tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "refresh_failed", "刷新登录失败")
		return
	}
	s.audit(r.Context(), "app:"+accountID, "app.session.refresh", "app_session", sessionID, "allowed", "low")
	writeJSON(w, http.StatusOK, map[string]any{"tokens": pair})
}

func (s *Server) handleAppSession(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		writeJSON(w, http.StatusOK, map[string]any{"account": map[string]any{
			"id": identity.AccountID, "username": identity.Username, "passwordChangeRequired": identity.PasswordChangeRequired,
		}})
		return
	}
	_, _ = s.db.ExecContext(r.Context(), "UPDATE app_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE id = ?", identity.SessionID)
	_, _ = s.db.ExecContext(r.Context(), "UPDATE ai_gateway_tokens SET revoked_at = UTC_TIMESTAMP(6) WHERE app_session_id = ? AND revoked_at IS NULL", identity.SessionID)
	s.audit(r.Context(), "app:"+identity.AccountID, "app.logout", "app_session", identity.SessionID, "allowed", "low")
	writeJSON(w, http.StatusOK, map[string]any{"loggedOut": true})
}

func (s *Server) handleAppDevices(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		s.listAppDevices(w, r, identity)
		return
	}
	s.revokeOtherAppDevices(w, r, identity)
}

func (s *Server) listAppDevices(w http.ResponseWriter, r *http.Request, identity *appIdentity) {
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, device_name, last_seen_at, created_at
      FROM app_sessions WHERE account_id = ? AND revoked_at IS NULL
        AND refresh_expires_at > UTC_TIMESTAMP(6)
      ORDER BY (id = ?) DESC, last_seen_at DESC LIMIT 100`, identity.AccountID, identity.SessionID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取登录设备")
		return
	}
	defer rows.Close()
	devices := make([]appDeviceSession, 0)
	for rows.Next() {
		var device appDeviceSession
		if err := rows.Scan(&device.ID, &device.Name, &device.LastSeenAt, &device.CreatedAt); err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取登录设备")
			return
		}
		device.Current = device.ID == identity.SessionID
		devices = append(devices, device)
	}
	if rows.Err() != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取登录设备")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"devices": devices})
}

func (s *Server) revokeOtherAppDevices(w http.ResponseWriter, r *http.Request, identity *appIdentity) {
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	_, err = tx.ExecContext(r.Context(), `UPDATE ai_gateway_tokens SET revoked_at = UTC_TIMESTAMP(6)
      WHERE account_id = ? AND app_session_id <> ? AND revoked_at IS NULL`,
		identity.AccountID, identity.SessionID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "session_revoke_failed", "退出其他设备失败")
		return
	}
	result, err := tx.ExecContext(r.Context(), `UPDATE app_sessions SET revoked_at = UTC_TIMESTAMP(6)
      WHERE account_id = ? AND id <> ? AND revoked_at IS NULL`,
		identity.AccountID, identity.SessionID)
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "session_revoke_failed", "退出其他设备失败")
		return
	}
	revoked, err := result.RowsAffected()
	if err != nil {
		revoked = 0
	}
	s.syncHub.revokeOtherSessions(identity.AccountID, identity.SessionID, "session_revoked")
	s.audit(r.Context(), "app:"+identity.AccountID, "app.sessions.revoke_others", "app_account", identity.AccountID, "allowed", "high")
	writeJSON(w, http.StatusOK, map[string]any{"revoked": revoked})
}

func (s *Server) handleAppPassword(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	var input struct {
		CurrentPassword string `json:"currentPassword"`
		NewPassword     string `json:"newPassword"`
	}
	if err := decodeJSON(r, &input); err != nil || input.CurrentPassword == input.NewPassword {
		writeError(w, http.StatusBadRequest, "invalid_request", "新密码不能与当前密码相同")
		return
	}
	account, err := s.appAccountByID(r, identity.AccountID)
	if err != nil || !security.VerifyPassword(input.CurrentPassword, "app", account.digest(), s.cfg.AuthMasterKey) {
		writeError(w, http.StatusUnauthorized, "invalid_credentials", "当前密码不正确")
		return
	}
	digest, err := security.HashPassword(input.NewPassword, "app", s.cfg.AuthMasterKey)
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
	_, err = tx.ExecContext(r.Context(), `UPDATE app_accounts SET password_algorithm = ?, password_hash = ?,
      password_salt = ?, password_iterations = ?, password_change_required = FALSE, failed_login_count = 0,
      locked_until = NULL, password_changed_at = UTC_TIMESTAMP(6) WHERE id = ? AND status = 'active'`,
		digest.Algorithm, digest.Hash, digest.Salt, digest.Iterations, identity.AccountID)
	if err == nil {
		_, err = tx.ExecContext(r.Context(), "UPDATE app_sessions SET revoked_at = UTC_TIMESTAMP(6) WHERE account_id = ? AND revoked_at IS NULL", identity.AccountID)
	}
	if err == nil {
		_, err = tx.ExecContext(r.Context(), "UPDATE ai_gateway_tokens SET revoked_at = UTC_TIMESTAMP(6) WHERE account_id = ? AND revoked_at IS NULL", identity.AccountID)
	}
	var pair appTokenPair
	if err == nil {
		pair, err = s.newAppSessionWith(r.Context(), tx, identity.AccountID, identity.DeviceName, identity.E2EETrusted)
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "password_change_failed", "修改密码失败")
		return
	}
	s.syncHub.revoke(identity.AccountID, "credentials_changed")
	s.audit(r.Context(), "app:"+identity.AccountID, "app.password.change", "app_account", identity.AccountID, "allowed", "critical")
	writeJSON(w, http.StatusOK, map[string]any{
		"account": map[string]any{"id": identity.AccountID, "username": identity.Username, "passwordChangeRequired": false},
		"tokens":  pair,
	})
}

func (s *Server) appAccountByUsername(r *http.Request, username string) (appAccountRecord, error) {
	return s.scanAppAccount(s.db.QueryRowContext(r.Context(), `SELECT id, username, password_algorithm,
      password_hash, password_salt, password_iterations, password_change_required, status, locked_until
      FROM app_accounts WHERE username_canonical = ? LIMIT 1`, strings.ToLower(strings.TrimSpace(username))))
}

func (s *Server) appAccountByID(r *http.Request, id string) (appAccountRecord, error) {
	return s.scanAppAccount(s.db.QueryRowContext(r.Context(), `SELECT id, username, password_algorithm,
      password_hash, password_salt, password_iterations, password_change_required, status, locked_until
      FROM app_accounts WHERE id = ? LIMIT 1`, id))
}

func (s *Server) scanAppAccount(row rowScanner) (appAccountRecord, error) {
	var account appAccountRecord
	err := row.Scan(&account.ID, &account.Username, &account.PasswordAlgorithm, &account.PasswordHash,
		&account.PasswordSalt, &account.PasswordIterations, &account.PasswordChangeRequired, &account.Status, &account.LockedUntil)
	return account, err
}

var _ = errors.Is
