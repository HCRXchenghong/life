package httpapi

import (
	"bytes"
	"database/sql"
	"encoding/base64"
	"errors"
	"net/http"
	"time"
)

const (
	deviceApprovalTTL        = 10 * time.Minute
	maxPendingDeviceRequests = 10
)

type deviceApprovalRequestInput struct {
	ID        string `json:"id"`
	PublicKey string `json:"publicKey"`
}

type deviceApprovalDecisionInput struct {
	ApproverPublicKey string `json:"approverPublicKey"`
	Nonce             string `json:"nonce"`
	Ciphertext        string `json:"ciphertext"`
	KeyVersion        int    `json:"keyVersion"`
}

type decodedDeviceApprovalDecision struct {
	ApproverPublicKey []byte
	Nonce             []byte
	Ciphertext        []byte
	KeyVersion        int
}

func (s *Server) handleDeviceApprovals(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		s.listPendingDeviceApprovals(w, r, identity)
		return
	}
	var input deviceApprovalRequestInput
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "设备批准请求无效")
		return
	}
	publicKey, err := decodeFixedBase64(input.PublicKey, 32)
	if !validUUIDLike(input.ID) || err != nil || allZero(publicKey) {
		writeError(w, http.StatusBadRequest, "invalid_request", "设备批准请求无效")
		return
	}
	if _, err = s.loadContentKeyEnvelope(r, identity.AccountID); errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusConflict, "content_key_missing", "该账号尚未开启端到端加密")
		return
	} else if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法创建设备批准请求")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var lockedAccount string
	if err = tx.QueryRowContext(r.Context(), `SELECT account_id FROM content_key_envelopes
		WHERE account_id = ? FOR UPDATE`, identity.AccountID).Scan(&lockedAccount); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法创建设备批准请求")
		return
	}
	_, err = tx.ExecContext(r.Context(), `UPDATE content_key_device_approvals SET status = 'expired'
		WHERE account_id = ? AND status = 'pending' AND expires_at <= UTC_TIMESTAMP(6)`, identity.AccountID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法创建设备批准请求")
		return
	}
	var pending int
	if err = tx.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM content_key_device_approvals
		WHERE account_id = ? AND status = 'pending' AND expires_at > UTC_TIMESTAMP(6)`, identity.AccountID).Scan(&pending); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法创建设备批准请求")
		return
	}
	if pending >= maxPendingDeviceRequests {
		writeError(w, http.StatusTooManyRequests, "too_many_device_requests", "待处理的新设备请求过多")
		return
	}
	expiresAt := time.Now().UTC().Add(deviceApprovalTTL)
	_, err = tx.ExecContext(r.Context(), `INSERT INTO content_key_device_approvals
		(id, account_id, requester_session_id, requester_device_name, requester_public_key, expires_at)
		VALUES (?, ?, ?, ?, ?, ?)`, input.ID, identity.AccountID, identity.SessionID,
		identity.DeviceName, publicKey, expiresAt)
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusConflict, "device_request_exists", "设备批准请求已存在或无法创建")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "app.e2ee.device.request", "device_approval", input.ID, "allowed", "high")
	writeJSON(w, http.StatusCreated, map[string]any{
		"id": input.ID, "status": "pending", "expiresAt": expiresAt,
	})
}

func (s *Server) listPendingDeviceApprovals(w http.ResponseWriter, r *http.Request, identity *appIdentity) {
	if !identity.E2EETrusted {
		writeError(w, http.StatusForbidden, "trusted_device_required", "只有受信设备可以查看批准请求")
		return
	}
	_, _ = s.db.ExecContext(r.Context(), `UPDATE content_key_device_approvals SET status = 'expired'
		WHERE account_id = ? AND status = 'pending' AND expires_at <= UTC_TIMESTAMP(6)`, identity.AccountID)
	rows, err := s.db.QueryContext(r.Context(), `SELECT id, requester_device_name, requester_public_key, created_at, expires_at
		FROM content_key_device_approvals WHERE account_id = ? AND requester_session_id <> ?
		AND status = 'pending' AND expires_at > UTC_TIMESTAMP(6)
		ORDER BY created_at ASC LIMIT 20`, identity.AccountID, identity.SessionID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取新设备请求")
		return
	}
	defer rows.Close()
	requests := make([]map[string]any, 0)
	for rows.Next() {
		var id, deviceName string
		var publicKey []byte
		var createdAt, expiresAt time.Time
		if err := rows.Scan(&id, &deviceName, &publicKey, &createdAt, &expiresAt); err != nil || len(publicKey) != 32 {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取新设备请求")
			return
		}
		requests = append(requests, map[string]any{
			"id": id, "deviceName": deviceName, "publicKey": base64.StdEncoding.EncodeToString(publicKey),
			"createdAt": createdAt, "expiresAt": expiresAt,
		})
	}
	if rows.Err() != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取新设备请求")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"requests": requests})
}

func (s *Server) handleDeviceApprovalStatus(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	id := r.PathValue("id")
	if !validUUIDLike(id) {
		writeError(w, http.StatusBadRequest, "invalid_request", "设备批准请求无效")
		return
	}
	var status, deviceName string
	var publicKey, approverPublicKey, nonce, ciphertext []byte
	var keyVersion sql.NullInt64
	var createdAt, expiresAt time.Time
	err := s.db.QueryRowContext(r.Context(), `SELECT status, requester_device_name, requester_public_key,
		COALESCE(approver_public_key, ''), COALESCE(approval_nonce, ''), COALESCE(approval_ciphertext, ''),
		key_version, created_at, expires_at FROM content_key_device_approvals
		WHERE id = ? AND account_id = ? LIMIT 1`, id, identity.AccountID).Scan(
		&status, &deviceName, &publicKey, &approverPublicKey, &nonce, &ciphertext,
		&keyVersion, &createdAt, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "device_request_not_found", "设备批准请求不存在")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取设备批准状态")
		return
	}
	if status == "pending" && !expiresAt.After(time.Now().UTC()) {
		status = "expired"
		_, _ = s.db.ExecContext(r.Context(), `UPDATE content_key_device_approvals SET status = 'expired'
			WHERE id = ? AND account_id = ? AND status = 'pending'`, id, identity.AccountID)
	}
	payload := map[string]any{
		"id": id, "status": status, "deviceName": deviceName,
		"publicKey": base64.StdEncoding.EncodeToString(publicKey),
		"createdAt": createdAt, "expiresAt": expiresAt,
	}
	if status == "approved" || status == "consumed" {
		if len(approverPublicKey) != 32 || len(nonce) != 12 || len(ciphertext) != 48 || !keyVersion.Valid {
			writeError(w, http.StatusServiceUnavailable, "invalid_approval_state", "设备批准状态无效")
			return
		}
		payload["approverPublicKey"] = base64.StdEncoding.EncodeToString(approverPublicKey)
		payload["nonce"] = base64.StdEncoding.EncodeToString(nonce)
		payload["ciphertext"] = base64.StdEncoding.EncodeToString(ciphertext)
		payload["keyVersion"] = keyVersion.Int64
	}
	writeJSON(w, http.StatusOK, payload)
}

func (s *Server) handleDeviceApprovalApprove(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if !identity.E2EETrusted {
		writeError(w, http.StatusForbidden, "trusted_device_required", "只有受信设备可以批准新设备")
		return
	}
	id := r.PathValue("id")
	var input deviceApprovalDecisionInput
	if !validUUIDLike(id) || decodeJSON(r, &input) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "设备批准结果无效")
		return
	}
	decision, err := decodeDeviceApprovalDecision(input)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "设备批准结果无效")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var requesterSessionID, status string
	var expiresAt time.Time
	var priorApprover sql.NullString
	var priorPublicKey, priorNonce, priorCiphertext []byte
	var priorVersion sql.NullInt64
	err = tx.QueryRowContext(r.Context(), `SELECT requester_session_id, status, expires_at,
		approver_session_id, COALESCE(approver_public_key, ''), COALESCE(approval_nonce, ''),
		COALESCE(approval_ciphertext, ''), key_version FROM content_key_device_approvals
		WHERE id = ? AND account_id = ? FOR UPDATE`, id, identity.AccountID).Scan(
		&requesterSessionID, &status, &expiresAt, &priorApprover, &priorPublicKey,
		&priorNonce, &priorCiphertext, &priorVersion)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "device_request_not_found", "设备批准请求不存在")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取设备批准请求")
		return
	}
	if status == "approved" && priorApprover.Valid && priorApprover.String == identity.SessionID &&
		priorVersion.Valid && int(priorVersion.Int64) == decision.KeyVersion &&
		bytes.Equal(priorPublicKey, decision.ApproverPublicKey) && bytes.Equal(priorNonce, decision.Nonce) &&
		bytes.Equal(priorCiphertext, decision.Ciphertext) {
		writeJSON(w, http.StatusOK, map[string]any{"approved": true, "idempotent": true})
		return
	}
	if requesterSessionID == identity.SessionID || status != "pending" || !expiresAt.After(time.Now().UTC()) {
		if status == "pending" && !expiresAt.After(time.Now().UTC()) {
			_, _ = tx.ExecContext(r.Context(), "UPDATE content_key_device_approvals SET status = 'expired' WHERE id = ?", id)
			_ = tx.Commit()
		}
		writeError(w, http.StatusConflict, "device_request_unavailable", "设备批准请求已失效")
		return
	}
	_, err = tx.ExecContext(r.Context(), `UPDATE content_key_device_approvals SET status = 'approved',
		approver_session_id = ?, approver_public_key = ?, approval_nonce = ?, approval_ciphertext = ?,
		key_version = ?, decided_at = UTC_TIMESTAMP(6) WHERE id = ? AND status = 'pending'`,
		identity.SessionID, decision.ApproverPublicKey, decision.Nonce, decision.Ciphertext,
		decision.KeyVersion, id)
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "device_approval_failed", "批准新设备失败")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "app.e2ee.device.approve", "device_approval", id, "allowed", "critical")
	writeJSON(w, http.StatusOK, map[string]any{"approved": true, "idempotent": false})
}

func (s *Server) handleDeviceApprovalReject(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if !identity.E2EETrusted {
		writeError(w, http.StatusForbidden, "trusted_device_required", "只有受信设备可以拒绝新设备")
		return
	}
	id := r.PathValue("id")
	if !validUUIDLike(id) {
		writeError(w, http.StatusBadRequest, "invalid_request", "设备批准请求无效")
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE content_key_device_approvals SET status = 'rejected',
		approver_session_id = ?, decided_at = UTC_TIMESTAMP(6) WHERE id = ? AND account_id = ?
		AND requester_session_id <> ? AND status = 'pending' AND expires_at > UTC_TIMESTAMP(6)`,
		identity.SessionID, id, identity.AccountID, identity.SessionID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "device_rejection_failed", "拒绝新设备失败")
		return
	}
	changed, _ := result.RowsAffected()
	if changed != 1 {
		writeError(w, http.StatusConflict, "device_request_unavailable", "设备批准请求已失效")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "app.e2ee.device.reject", "device_approval", id, "allowed", "high")
	writeJSON(w, http.StatusOK, map[string]any{"rejected": true})
}

func (s *Server) handleDeviceApprovalConsume(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	id := r.PathValue("id")
	if !validUUIDLike(id) {
		writeError(w, http.StatusBadRequest, "invalid_request", "设备批准请求无效")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var status, requesterSessionID string
	err = tx.QueryRowContext(r.Context(), `SELECT status, requester_session_id
		FROM content_key_device_approvals WHERE id = ? AND account_id = ? FOR UPDATE`,
		id, identity.AccountID).Scan(&status, &requesterSessionID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "device_request_not_found", "设备批准请求不存在")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取设备批准请求")
		return
	}
	if requesterSessionID != identity.SessionID {
		writeError(w, http.StatusForbidden, "requester_device_required", "只有发起请求的设备可以完成批准")
		return
	}
	if status == "consumed" {
		writeJSON(w, http.StatusOK, map[string]any{"consumed": true, "idempotent": true})
		return
	}
	if status != "approved" {
		writeError(w, http.StatusConflict, "device_request_unavailable", "设备批准请求尚未完成")
		return
	}
	_, err = tx.ExecContext(r.Context(), `UPDATE content_key_device_approvals SET status = 'consumed',
		consumed_at = UTC_TIMESTAMP(6) WHERE id = ? AND account_id = ? AND status = 'approved'`, id, identity.AccountID)
	if err == nil {
		_, err = tx.ExecContext(r.Context(), `UPDATE app_sessions SET e2ee_trusted = TRUE
			WHERE id = ? AND account_id = ? AND revoked_at IS NULL`, identity.SessionID, identity.AccountID)
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "device_consume_failed", "设备批准完成状态保存失败")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "app.e2ee.device.consume", "device_approval", id, "allowed", "high")
	writeJSON(w, http.StatusOK, map[string]any{"consumed": true, "idempotent": false})
}

func decodeDeviceApprovalDecision(input deviceApprovalDecisionInput) (decodedDeviceApprovalDecision, error) {
	publicKey, publicErr := decodeFixedBase64(input.ApproverPublicKey, 32)
	nonce, nonceErr := decodeFixedBase64(input.Nonce, 12)
	ciphertext, ciphertextErr := decodeFixedBase64(input.Ciphertext, 48)
	if publicErr != nil || nonceErr != nil || ciphertextErr != nil || allZero(publicKey) ||
		input.KeyVersion < 1 || input.KeyVersion > 1_000_000 {
		return decodedDeviceApprovalDecision{}, errors.New("invalid device approval decision")
	}
	return decodedDeviceApprovalDecision{publicKey, nonce, ciphertext, input.KeyVersion}, nil
}

func decodeFixedBase64(value string, length int) ([]byte, error) {
	if value == "" || len(value) > 256 {
		return nil, errors.New("invalid base64 value")
	}
	decoded, err := base64.StdEncoding.DecodeString(value)
	if err != nil || len(decoded) != length {
		return nil, errors.New("invalid base64 value")
	}
	return decoded, nil
}

func allZero(value []byte) bool {
	var aggregate byte
	for _, item := range value {
		aggregate |= item
	}
	return aggregate == 0
}
