package httpapi

import (
	"bytes"
	"database/sql"
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"regexp"
	"strconv"
	"strings"
	"time"
)

var syncNamePattern = regexp.MustCompile(`^[a-z][a-z0-9_]{1,63}$`)

const recoveryKeyRotationTTL = 24 * time.Hour

type syncMutation struct {
	OperationID      string    `json:"operationId"`
	DeviceID         string    `json:"deviceId"`
	ExpectedRevision int64     `json:"expectedRevision"`
	Revision         int64     `json:"revision"`
	Ciphertext       string    `json:"ciphertext"`
	Nonce            string    `json:"nonce"`
	KeyVersion       int       `json:"keyVersion"`
	ClientUpdatedAt  time.Time `json:"clientUpdatedAt"`
}

type contentKeyEnvelopeInput struct {
	KeyVersion      int    `json:"keyVersion"`
	Algorithm       string `json:"algorithm"`
	KDF             string `json:"kdf"`
	Salt            string `json:"salt"`
	Nonce           string `json:"nonce"`
	Ciphertext      string `json:"ciphertext"`
	CreatorDeviceID string `json:"creatorDeviceId"`
}

type contentKeyEnvelopeRotationInput struct {
	RotationID       string                  `json:"rotationId"`
	ExpectedRevision int64                   `json:"expectedRevision"`
	Envelope         contentKeyEnvelopeInput `json:"envelope"`
}

type decodedContentKeyEnvelope struct {
	EnvelopeRevision int64
	KeyVersion       int
	Algorithm        string
	KDF              string
	Salt             []byte
	Nonce            []byte
	Ciphertext       []byte
	CreatorDeviceID  string
}

type decodedRecoveryKeyRotation struct {
	RotationID       string
	ExpectedRevision int64
	Envelope         decodedContentKeyEnvelope
}

func (s *Server) handleContentKeyEnvelope(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		s.getContentKeyEnvelope(w, r, identity)
		return
	}
	var input contentKeyEnvelopeInput
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	envelope, err := decodeContentKeyEnvelope(input)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_key_envelope", "恢复密钥信封无效")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "恢复密钥信封保存失败")
		return
	}
	defer func() { _ = tx.Rollback() }()
	result, err := tx.ExecContext(r.Context(), `INSERT INTO content_key_envelopes
		(account_id, key_version, algorithm, kdf, salt, nonce, ciphertext, creator_device_id)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)`, identity.AccountID, envelope.KeyVersion, envelope.Algorithm,
		envelope.KDF, envelope.Salt, envelope.Nonce, envelope.Ciphertext, envelope.CreatorDeviceID)
	if err == nil {
		if rows, rowsErr := result.RowsAffected(); rowsErr != nil || rows != 1 {
			writeError(w, http.StatusInternalServerError, "key_envelope_failed", "恢复密钥信封保存失败")
			return
		}
		trusted, trustErr := tx.ExecContext(r.Context(), `UPDATE app_sessions SET e2ee_trusted = TRUE
			WHERE id = ? AND account_id = ? AND revoked_at IS NULL`, identity.SessionID, identity.AccountID)
		if trustErr != nil {
			writeError(w, http.StatusInternalServerError, "key_envelope_failed", "恢复密钥信封保存失败")
			return
		}
		if rows, rowsErr := trusted.RowsAffected(); rowsErr != nil || rows != 1 || tx.Commit() != nil {
			writeError(w, http.StatusInternalServerError, "key_envelope_failed", "恢复密钥信封保存失败")
			return
		}
		s.audit(r.Context(), "app:"+identity.AccountID, "app.e2ee.initialize", "app_account", identity.AccountID, "allowed", "high")
		writeJSON(w, http.StatusCreated, map[string]any{"created": true, "keyVersion": envelope.KeyVersion})
		return
	}
	_ = tx.Rollback()
	existing, loadErr := s.loadContentKeyEnvelope(r, identity.AccountID)
	if loadErr != nil {
		writeError(w, http.StatusInternalServerError, "key_envelope_failed", "恢复密钥信封保存失败")
		return
	}
	if sameContentKeyEnvelope(existing, envelope) {
		writeJSON(w, http.StatusOK, map[string]any{"created": false, "keyVersion": envelope.KeyVersion})
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "app.e2ee.initialize", "app_account", identity.AccountID, "denied", "high")
	writeError(w, http.StatusConflict, "key_envelope_exists", "该账号已存在其他内容密钥")
}

func (s *Server) getContentKeyEnvelope(w http.ResponseWriter, r *http.Request, identity *appIdentity) {
	envelope, err := s.loadContentKeyEnvelope(r, identity.AccountID)
	if errors.Is(err, sql.ErrNoRows) {
		writeJSON(w, http.StatusOK, map[string]any{"exists": false})
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法读取恢复密钥信封")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"exists": true, "envelopeRevision": envelope.EnvelopeRevision,
		"keyVersion": envelope.KeyVersion, "algorithm": envelope.Algorithm,
		"kdf": envelope.KDF, "salt": base64.StdEncoding.EncodeToString(envelope.Salt),
		"nonce":           base64.StdEncoding.EncodeToString(envelope.Nonce),
		"ciphertext":      base64.StdEncoding.EncodeToString(envelope.Ciphertext),
		"creatorDeviceId": envelope.CreatorDeviceID,
	})
}

func (s *Server) loadContentKeyEnvelope(r *http.Request, accountID string) (decodedContentKeyEnvelope, error) {
	var envelope decodedContentKeyEnvelope
	err := s.db.QueryRowContext(r.Context(), `SELECT envelope_revision, key_version, algorithm, kdf, salt, nonce, ciphertext, creator_device_id
		FROM content_key_envelopes WHERE account_id = ? LIMIT 1`, accountID).Scan(
		&envelope.EnvelopeRevision, &envelope.KeyVersion, &envelope.Algorithm, &envelope.KDF, &envelope.Salt, &envelope.Nonce,
		&envelope.Ciphertext, &envelope.CreatorDeviceID)
	return envelope, err
}

func (s *Server) handleRecoveryKeyRotation(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if !identity.E2EETrusted {
		writeError(w, http.StatusForbidden, "trusted_device_required", "只有受信设备可以重新生成恢复密钥")
		return
	}
	var input contentKeyEnvelopeRotationInput
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "恢复密钥轮换请求无效")
		return
	}
	rotation, err := decodeRecoveryKeyRotation(input)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "恢复密钥轮换请求无效")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法开始恢复密钥轮换")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var currentRevision int64
	if err = tx.QueryRowContext(r.Context(), `SELECT envelope_revision FROM content_key_envelopes
		WHERE account_id = ? FOR UPDATE`, identity.AccountID).Scan(&currentRevision); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusConflict, "key_envelope_missing", "该账号尚未开启端到端加密")
		} else {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法开始恢复密钥轮换")
		}
		return
	}
	if currentRevision != rotation.ExpectedRevision {
		writeError(w, http.StatusConflict, "rotation_stale", "恢复密钥已在其他设备更新")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `DELETE FROM content_key_envelope_rotations
		WHERE account_id = ? AND expires_at <= UTC_TIMESTAMP(6)`, identity.AccountID); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法开始恢复密钥轮换")
		return
	}
	var existingID string
	var existingExpected int64
	var existing decodedContentKeyEnvelope
	var existingExpiry time.Time
	err = tx.QueryRowContext(r.Context(), `SELECT rotation_id, expected_revision, key_version,
		algorithm, kdf, salt, nonce, ciphertext, creator_device_id, expires_at
		FROM content_key_envelope_rotations WHERE account_id = ? FOR UPDATE`, identity.AccountID).Scan(
		&existingID, &existingExpected, &existing.KeyVersion, &existing.Algorithm, &existing.KDF,
		&existing.Salt, &existing.Nonce, &existing.Ciphertext, &existing.CreatorDeviceID, &existingExpiry)
	if err == nil {
		if existingID == rotation.RotationID && existingExpected == rotation.ExpectedRevision && sameContentKeyEnvelope(existing, rotation.Envelope) {
			writeJSON(w, http.StatusOK, map[string]any{
				"rotationId": existingID, "expectedRevision": existingExpected,
				"expiresAt": existingExpiry, "created": false,
			})
			return
		}
		writeError(w, http.StatusConflict, "rotation_in_progress", "另一台受信设备正在更新恢复密钥")
		return
	}
	if !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法开始恢复密钥轮换")
		return
	}
	expiresAt := time.Now().UTC().Add(recoveryKeyRotationTTL)
	result, err := tx.ExecContext(r.Context(), `INSERT INTO content_key_envelope_rotations
		(account_id, rotation_id, expected_revision, key_version, algorithm, kdf, salt, nonce,
		ciphertext, creator_device_id, expires_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		identity.AccountID, rotation.RotationID, rotation.ExpectedRevision, rotation.Envelope.KeyVersion,
		rotation.Envelope.Algorithm, rotation.Envelope.KDF, rotation.Envelope.Salt, rotation.Envelope.Nonce,
		rotation.Envelope.Ciphertext, rotation.Envelope.CreatorDeviceID, expiresAt)
	if err != nil {
		writeError(w, http.StatusConflict, "rotation_in_progress", "另一台受信设备正在更新恢复密钥")
		return
	}
	rows, rowsErr := result.RowsAffected()
	if rowsErr != nil || rows != 1 || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "rotation_failed", "恢复密钥轮换创建失败")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "app.e2ee.recovery.rotate.begin", "recovery_key_rotation", rotation.RotationID, "allowed", "high")
	writeJSON(w, http.StatusCreated, map[string]any{
		"rotationId": rotation.RotationID, "expectedRevision": rotation.ExpectedRevision,
		"expiresAt": expiresAt, "created": true,
	})
}

func decodeRecoveryKeyRotation(input contentKeyEnvelopeRotationInput) (decodedRecoveryKeyRotation, error) {
	rotationID := strings.ToLower(strings.TrimSpace(input.RotationID))
	if !validUUIDLike(rotationID) || input.ExpectedRevision < 1 {
		return decodedRecoveryKeyRotation{}, errors.New("invalid recovery key rotation metadata")
	}
	envelope, err := decodeContentKeyEnvelope(input.Envelope)
	if err != nil {
		return decodedRecoveryKeyRotation{}, err
	}
	return decodedRecoveryKeyRotation{
		RotationID: rotationID, ExpectedRevision: input.ExpectedRevision, Envelope: envelope,
	}, nil
}

func (s *Server) handleRecoveryKeyRotationCommit(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if !identity.E2EETrusted {
		writeError(w, http.StatusForbidden, "trusted_device_required", "只有受信设备可以启用新的恢复密钥")
		return
	}
	rotationID := strings.ToLower(strings.TrimSpace(r.PathValue("id")))
	if !validUUIDLike(rotationID) {
		writeError(w, http.StatusBadRequest, "invalid_request", "恢复密钥轮换标识无效")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法启用新的恢复密钥")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var currentRevision int64
	if err = tx.QueryRowContext(r.Context(), `SELECT envelope_revision FROM content_key_envelopes
		WHERE account_id = ? FOR UPDATE`, identity.AccountID).Scan(&currentRevision); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			writeError(w, http.StatusConflict, "key_envelope_missing", "该账号尚未开启端到端加密")
		} else {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法启用新的恢复密钥")
		}
		return
	}
	var expectedRevision int64
	var envelope decodedContentKeyEnvelope
	err = tx.QueryRowContext(r.Context(), `SELECT expected_revision, key_version, algorithm, kdf,
		salt, nonce, ciphertext, creator_device_id FROM content_key_envelope_rotations
		WHERE account_id = ? AND rotation_id = ? AND expires_at > UTC_TIMESTAMP(6) FOR UPDATE`,
		identity.AccountID, rotationID).Scan(&expectedRevision, &envelope.KeyVersion, &envelope.Algorithm,
		&envelope.KDF, &envelope.Salt, &envelope.Nonce, &envelope.Ciphertext, &envelope.CreatorDeviceID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusConflict, "rotation_missing", "恢复密钥轮换已失效或已完成")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "暂时无法启用新的恢复密钥")
		return
	}
	if expectedRevision != currentRevision {
		writeError(w, http.StatusConflict, "rotation_stale", "恢复密钥已在其他设备更新")
		return
	}
	result, err := tx.ExecContext(r.Context(), `UPDATE content_key_envelopes SET
		envelope_revision = envelope_revision + 1, key_version = ?, algorithm = ?, kdf = ?, salt = ?,
		nonce = ?, ciphertext = ?, creator_device_id = ? WHERE account_id = ? AND envelope_revision = ?`,
		envelope.KeyVersion, envelope.Algorithm, envelope.KDF, envelope.Salt, envelope.Nonce,
		envelope.Ciphertext, envelope.CreatorDeviceID, identity.AccountID, expectedRevision)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "rotation_failed", "新的恢复密钥启用失败")
		return
	}
	rows, rowsErr := result.RowsAffected()
	if rowsErr != nil || rows != 1 {
		writeError(w, http.StatusConflict, "rotation_stale", "恢复密钥已在其他设备更新")
		return
	}
	if _, err = tx.ExecContext(r.Context(), `DELETE FROM content_key_envelope_rotations
		WHERE account_id = ? AND rotation_id = ?`, identity.AccountID, rotationID); err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "rotation_failed", "新的恢复密钥启用失败")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "app.e2ee.recovery.rotate.commit", "recovery_key_rotation", rotationID, "allowed", "high")
	writeJSON(w, http.StatusOK, map[string]any{
		"rotationId": rotationID, "envelopeRevision": expectedRevision + 1, "committed": true,
	})
}

func decodeContentKeyEnvelope(input contentKeyEnvelopeInput) (decodedContentKeyEnvelope, error) {
	if input.KeyVersion != 1 || input.Algorithm != "aes-256-gcm" || input.KDF != "hkdf-sha256" ||
		!validUUIDLike(input.CreatorDeviceID) {
		return decodedContentKeyEnvelope{}, errors.New("unsupported key envelope metadata")
	}
	salt, err := base64.StdEncoding.DecodeString(input.Salt)
	if err != nil || len(salt) != 32 {
		return decodedContentKeyEnvelope{}, errors.New("invalid recovery salt")
	}
	nonce, err := base64.StdEncoding.DecodeString(input.Nonce)
	if err != nil || len(nonce) != 12 {
		return decodedContentKeyEnvelope{}, errors.New("invalid recovery nonce")
	}
	ciphertext, err := base64.StdEncoding.DecodeString(input.Ciphertext)
	if err != nil || len(ciphertext) != 48 {
		return decodedContentKeyEnvelope{}, errors.New("invalid recovery ciphertext")
	}
	return decodedContentKeyEnvelope{
		KeyVersion: input.KeyVersion, Algorithm: input.Algorithm, KDF: input.KDF,
		Salt: salt, Nonce: nonce, Ciphertext: ciphertext, CreatorDeviceID: input.CreatorDeviceID,
	}, nil
}

func sameContentKeyEnvelope(left, right decodedContentKeyEnvelope) bool {
	return left.KeyVersion == right.KeyVersion && left.Algorithm == right.Algorithm &&
		left.KDF == right.KDF && left.CreatorDeviceID == right.CreatorDeviceID &&
		bytes.Equal(left.Salt, right.Salt) && bytes.Equal(left.Nonce, right.Nonce) &&
		bytes.Equal(left.Ciphertext, right.Ciphertext)
}

func (s *Server) handleSyncObject(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	collection := r.PathValue("collection")
	objectID := r.PathValue("id")
	if !syncNamePattern.MatchString(collection) || !validUUIDLike(objectID) {
		writeError(w, http.StatusBadRequest, "invalid_request", "同步对象标识无效")
		return
	}
	if r.Method == http.MethodDelete {
		expected, err := strconv.ParseInt(r.URL.Query().Get("expectedRevision"), 10, 64)
		operationID := r.URL.Query().Get("operationId")
		deviceID := r.URL.Query().Get("deviceId")
		if err != nil || expected < 1 || !validUUIDLike(operationID) || !validUUIDLike(deviceID) {
			writeError(w, http.StatusBadRequest, "invalid_request", "expectedRevision 无效")
			return
		}
		s.mutateSyncObject(w, r, identity, collection, objectID, syncMutation{
			OperationID: operationID, DeviceID: deviceID, ExpectedRevision: expected, Revision: expected + 1,
		}, true)
		return
	}
	var input syncMutation
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if !validUUIDLike(input.OperationID) || !validUUIDLike(input.DeviceID) || input.Revision < 1 ||
		input.Revision != input.ExpectedRevision+1 || input.KeyVersion < 1 || input.KeyVersion > 1_000_000 ||
		input.ClientUpdatedAt.IsZero() {
		writeError(w, http.StatusBadRequest, "invalid_request", "同步修订信息无效")
		return
	}
	ciphertext, err := base64.StdEncoding.DecodeString(input.Ciphertext)
	if err != nil || len(ciphertext) == 0 || len(ciphertext) > 2<<20 {
		writeError(w, http.StatusBadRequest, "invalid_request", "加密内容无效或超过 2 MiB")
		return
	}
	nonce, err := base64.StdEncoding.DecodeString(input.Nonce)
	if err != nil || len(nonce) < 12 || len(nonce) > 64 {
		writeError(w, http.StatusBadRequest, "invalid_request", "加密 nonce 无效")
		return
	}
	input.Ciphertext = base64.StdEncoding.EncodeToString(ciphertext)
	input.Nonce = base64.StdEncoding.EncodeToString(nonce)
	s.mutateSyncObject(w, r, identity, collection, objectID, input, false)
}

func (s *Server) mutateSyncObject(w http.ResponseWriter, r *http.Request, identity *appIdentity, collection, objectID string, input syncMutation, deleted bool) {
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var priorCursor, priorRevision int64
	var priorCollection, priorObject string
	err = tx.QueryRowContext(r.Context(), `SELECT sequence_id, collection_name, object_id, revision
		FROM sync_events WHERE account_id = ? AND operation_id = ? LIMIT 1`,
		identity.AccountID, input.OperationID).Scan(&priorCursor, &priorCollection, &priorObject, &priorRevision)
	if err == nil {
		if priorCollection != collection || priorObject != objectID || priorRevision != input.Revision {
			writeError(w, http.StatusConflict, "operation_conflict", "同步操作标识已用于其他变更")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"revision": priorRevision, "cursor": priorCursor, "idempotent": true})
		return
	}
	if !errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	var current int64
	err = tx.QueryRowContext(r.Context(), `SELECT revision FROM sync_objects
      WHERE account_id = ? AND collection_name = ? AND object_id = ? FOR UPDATE`,
		identity.AccountID, collection, objectID).Scan(&current)
	if errors.Is(err, sql.ErrNoRows) {
		current = 0
	} else if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if current != input.ExpectedRevision {
		writeJSON(w, http.StatusConflict, map[string]any{"error": apiError{Code: "revision_conflict", Message: "同步对象已被其他设备更新"}, "currentRevision": current})
		return
	}
	if deleted && current == 0 {
		writeError(w, http.StatusNotFound, "not_found", "同步对象不存在")
		return
	}
	var ciphertext, nonce []byte
	if deleted {
		ciphertext, nonce = []byte{0}, []byte{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
		input.KeyVersion = 1
		input.ClientUpdatedAt = time.Now().UTC()
	} else {
		ciphertext, _ = base64.StdEncoding.DecodeString(input.Ciphertext)
		nonce, _ = base64.StdEncoding.DecodeString(input.Nonce)
	}
	_, err = tx.ExecContext(r.Context(), `INSERT INTO sync_objects
		(account_id, collection_name, object_id, revision, ciphertext, nonce, key_version, last_device_id, deleted, client_updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE revision = VALUES(revision), ciphertext = VALUES(ciphertext), nonce = VALUES(nonce),
		key_version = VALUES(key_version), last_device_id = VALUES(last_device_id), deleted = VALUES(deleted),
		client_updated_at = VALUES(client_updated_at)`, identity.AccountID, collection, objectID, input.Revision,
		ciphertext, nonce, input.KeyVersion, input.DeviceID, deleted, input.ClientUpdatedAt.UTC())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "sync_failed", "同步写入失败")
		return
	}
	result, err := tx.ExecContext(r.Context(), `INSERT INTO sync_events
		(account_id, collection_name, object_id, operation_id, device_id, revision, deleted, ciphertext, nonce, key_version, client_updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`, identity.AccountID, collection, objectID,
		input.OperationID, input.DeviceID, input.Revision, deleted, ciphertext, nonce, input.KeyVersion, input.ClientUpdatedAt.UTC())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "sync_failed", "同步写入失败")
		return
	}
	sequence, _ := result.LastInsertId()
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "sync_failed", "同步写入失败")
		return
	}
	s.syncHub.publish(identity.AccountID)
	writeJSON(w, http.StatusOK, map[string]any{"revision": input.Revision, "cursor": sequence})
}

func (s *Server) handleSyncChanges(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	cursor, _ := strconv.ParseInt(r.URL.Query().Get("cursor"), 10, 64)
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit < 1 || limit > 500 {
		limit = 200
	}
	rows, err := s.db.QueryContext(r.Context(), `SELECT sequence_id, collection_name, object_id,
		operation_id, device_id, revision, deleted, ciphertext, nonce, key_version, client_updated_at, created_at
		FROM sync_events WHERE account_id = ? AND sequence_id > ? ORDER BY sequence_id ASC LIMIT ?`,
		identity.AccountID, cursor, limit)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer rows.Close()
	changes := make([]map[string]any, 0)
	nextCursor := cursor
	for rows.Next() {
		var sequence, revision int64
		var collection, objectID, operationID, deviceID string
		var deleted bool
		var ciphertext, nonce []byte
		var keyVersion int
		var clientUpdated, serverUpdated time.Time
		if err := rows.Scan(&sequence, &collection, &objectID, &operationID, &deviceID, &revision, &deleted, &ciphertext, &nonce,
			&keyVersion, &clientUpdated, &serverUpdated); err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		nextCursor = sequence
		change := map[string]any{"cursor": sequence, "collection": collection, "id": objectID,
			"operationId": operationID, "deviceId": deviceID,
			"revision": revision, "deleted": deleted, "clientUpdatedAt": clientUpdated, "serverUpdatedAt": serverUpdated}
		if !deleted {
			change["ciphertext"] = base64.StdEncoding.EncodeToString(ciphertext)
			change["nonce"] = base64.StdEncoding.EncodeToString(nonce)
			change["keyVersion"] = keyVersion
		}
		changes = append(changes, change)
	}
	if rows.Err() != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"changes": changes, "cursor": nextCursor, "hasMore": len(changes) == limit})
}

func (s *Server) handleSyncEvents(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if err := http.NewResponseController(w).SetWriteDeadline(time.Time{}); err != nil && !errors.Is(err, http.ErrNotSupported) {
		writeError(w, http.StatusInternalServerError, "streaming_unavailable", "当前网关不支持实时连接")
		return
	}
	flusher, ok := w.(http.Flusher)
	if !ok {
		writeError(w, http.StatusNotImplemented, "streaming_unavailable", "当前网关不支持实时连接")
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-store")
	w.Header().Set("Connection", "keep-alive")
	w.Header().Set("X-Accel-Buffering", "no")
	channel, unsubscribe := s.syncHub.subscribe(identity.AccountID, identity.SessionID)
	defer unsubscribe()
	_, _ = fmt.Fprint(w, "event: ready\ndata: {}\n\n")
	flusher.Flush()
	keepAlive := time.NewTicker(20 * time.Second)
	defer keepAlive.Stop()
	for {
		select {
		case <-r.Context().Done():
			return
		case event := <-channel:
			if event.Name == "session_revoked" {
				_, _ = fmt.Fprintf(w, "event: session_revoked\ndata: {\"reason\":%q}\n\n", event.Reason)
				flusher.Flush()
				return
			}
			_, _ = fmt.Fprint(w, "event: changes\ndata: {}\n\n")
			flusher.Flush()
		case <-keepAlive.C:
			var active bool
			err := s.db.QueryRowContext(r.Context(), `SELECT EXISTS(
				SELECT 1 FROM app_sessions s JOIN app_accounts a ON a.id = s.account_id
				WHERE s.id = ? AND s.account_id = ? AND s.revoked_at IS NULL AND a.status = 'active'
			)`, identity.SessionID, identity.AccountID).Scan(&active)
			if err != nil || !active {
				_, _ = fmt.Fprint(w, "event: session_revoked\ndata: {\"reason\":\"session_revoked\"}\n\n")
				flusher.Flush()
				return
			}
			_, _ = fmt.Fprint(w, ": keepalive\n\n")
			flusher.Flush()
		}
	}
}

func validUUIDLike(value string) bool {
	if len(value) != 36 {
		return false
	}
	for index, r := range value {
		if index == 8 || index == 13 || index == 18 || index == 23 {
			if r != '-' {
				return false
			}
			continue
		}
		if !strings.ContainsRune("0123456789abcdefABCDEF", r) {
			return false
		}
	}
	return true
}
