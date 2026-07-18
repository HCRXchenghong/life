package httpapi

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"sort"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

const (
	maximumPollFriends         = 50
	maximumSelectionsPerFriend = 200
	minimumSelectionDuration   = 5 * time.Minute
	maximumSelectionDuration   = 24 * time.Hour
)

type ownedPollRecord struct {
	ID             string
	AccountID      string
	Title          string
	Description    string
	Timezone       string
	Status         string
	ClosesAt       sql.NullTime
	SelectedStarts sql.NullTime
	SelectedEnds   sql.NullTime
	Version        int64
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type pollTimeRange struct {
	ID       string
	Label    string
	StartsAt time.Time
	EndsAt   time.Time
}

type pollFriendSelection struct {
	ID       string
	InviteID string
	StartsAt time.Time
	EndsAt   time.Time
}

type friendSelectionInput struct {
	StartsAt time.Time `json:"startsAt"`
	EndsAt   time.Time `json:"endsAt"`
}

type publicFriendInviteRecord struct {
	InviteID     string
	DisplayName  string
	InviteStatus string
	Poll         ownedPollRecord
}

func (s *Server) handleOwnedPollDetails(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	poll, err := s.ownedPollByID(r.Context(), r.PathValue("id"), identity.AccountID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "活动不存在")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	ranges, err := s.pollTimeRanges(r.Context(), poll.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}

	rows, err := s.db.QueryContext(r.Context(), `SELECT id, display_name, access_token_ciphertext,
      access_token_nonce, status, submitted_at, created_at, updated_at
      FROM poll_friend_invites WHERE poll_id = ? AND status <> 'revoked' ORDER BY created_at`, poll.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer rows.Close()
	invites := make([]map[string]any, 0)
	inviteIDs := make([]string, 0)
	for rows.Next() {
		var id, name, status string
		var ciphertext, nonce []byte
		var submitted sql.NullTime
		var created, updated time.Time
		if err := rows.Scan(&id, &name, &ciphertext, &nonce, &status, &submitted, &created, &updated); err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		token, err := security.Decrypt(s.cfg.AuthMasterKey, "poll-invite:"+id, ciphertext, nonce)
		if err != nil || len(token) < 20 {
			writeError(w, http.StatusServiceUnavailable, "invite_unavailable", "专属邀请暂时不可用")
			return
		}
		inviteIDs = append(inviteIDs, id)
		invites = append(invites, map[string]any{
			"id": id, "displayName": name, "status": status, "submittedAt": nullableTime(submitted),
			"createdAt": created, "updatedAt": updated,
			"inviteUrl":  s.cfg.PublicOrigin + "/select/" + string(token),
			"selections": make([]map[string]any, 0),
		})
	}
	if err := rows.Err(); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	selections, err := s.friendSelectionsForPoll(r.Context(), poll.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	byInvite := make(map[string][]map[string]any, len(inviteIDs))
	for _, selection := range selections {
		byInvite[selection.InviteID] = append(byInvite[selection.InviteID], selectionJSON(selection))
	}
	for _, invite := range invites {
		id := invite["id"].(string)
		if values := byInvite[id]; values != nil {
			invite["selections"] = values
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"poll":        ownedPollJSON(poll),
		"ranges":      rangesJSON(ranges),
		"invites":     invites,
		"suggestions": aggregateFriendSelections(selections),
	})
}

func (s *Server) handlePollFriendInvites(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	var input struct {
		DisplayName string `json:"displayName"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	input.DisplayName = strings.TrimSpace(input.DisplayName)
	if utf8.RuneCountInString(input.DisplayName) < 1 || utf8.RuneCountInString(input.DisplayName) > 80 || strings.ContainsAny(input.DisplayName, "\r\n\x00") {
		writeError(w, http.StatusBadRequest, "invalid_request", "朋友姓名需为 1–80 个字符")
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "poll_friend_invite", identity.AccountID, 80); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "邀请服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "生成邀请过于频繁，请稍后重试")
		return
	}

	inviteID, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "invite_failed", "暂时无法生成邀请")
		return
	}
	token, err := security.RandomToken("dli_")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "invite_failed", "暂时无法生成邀请")
		return
	}
	ciphertext, nonce, err := security.Encrypt(s.cfg.AuthMasterKey, "poll-invite:"+inviteID, []byte(token))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "invite_failed", "暂时无法生成邀请")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var status string
	var closes sql.NullTime
	var version int64
	err = tx.QueryRowContext(r.Context(), `SELECT status, closes_at, version FROM share_polls
      WHERE id = ? AND account_id = ? FOR UPDATE`, r.PathValue("id"), identity.AccountID).Scan(&status, &closes, &version)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "活动不存在")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if !pollIsOpen(status, closes, time.Now().UTC()) {
		writeError(w, http.StatusConflict, "poll_closed", "活动已结束")
		return
	}
	var generated int
	if err := tx.QueryRowContext(r.Context(), "SELECT COUNT(*) FROM poll_friend_invites WHERE poll_id = ?", r.PathValue("id")).Scan(&generated); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if generated >= maximumPollFriends {
		writeError(w, http.StatusConflict, "friend_limit_reached", "每个活动最多邀请 50 位朋友")
		return
	}
	now := time.Now().UTC()
	_, err = tx.ExecContext(r.Context(), `INSERT INTO poll_friend_invites
      (id, poll_id, display_name, access_token_hash, access_token_ciphertext, access_token_nonce)
      VALUES (?, ?, ?, ?, ?, ?)`, inviteID, r.PathValue("id"), input.DisplayName, security.SHA256(token), ciphertext, nonce)
	if err == nil {
		_, err = tx.ExecContext(r.Context(), "UPDATE share_polls SET version = version + 1 WHERE id = ?", r.PathValue("id"))
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "invite_failed", "暂时无法生成邀请")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "poll.friend_invite.create", "share_poll", r.PathValue("id"), "allowed", "low")
	s.syncHub.publish(identity.AccountID)
	writeJSON(w, http.StatusCreated, map[string]any{
		"invite": map[string]any{
			"id": inviteID, "displayName": input.DisplayName, "status": "pending", "submittedAt": nil,
			"createdAt": now, "updatedAt": now, "inviteUrl": s.cfg.PublicOrigin + "/select/" + token,
			"selections": []any{},
		},
		"pollVersion": version + 1,
	})
}

func (s *Server) handlePollFriendInvite(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var pollID string
	err = tx.QueryRowContext(r.Context(), "SELECT id FROM share_polls WHERE id = ? AND account_id = ? FOR UPDATE", r.PathValue("id"), identity.AccountID).Scan(&pollID)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "活动不存在")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	result, err := tx.ExecContext(r.Context(), `UPDATE poll_friend_invites SET status = 'revoked',
      revoked_at = UTC_TIMESTAMP(6) WHERE id = ? AND poll_id = ? AND status <> 'revoked'`, r.PathValue("inviteId"), r.PathValue("id"))
	if err != nil {
		writeError(w, http.StatusInternalServerError, "invite_revoke_failed", "暂时无法撤销邀请")
		return
	}
	changed, _ := result.RowsAffected()
	if changed != 1 {
		writeError(w, http.StatusNotFound, "not_found", "专属邀请不存在")
		return
	}
	if _, err = tx.ExecContext(r.Context(), "UPDATE share_polls SET version = version + 1 WHERE id = ?", r.PathValue("id")); err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "invite_revoke_failed", "暂时无法撤销邀请")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "poll.friend_invite.revoke", "share_poll", r.PathValue("id"), "allowed", "medium")
	s.syncHub.publish(identity.AccountID)
	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) handlePublicPollInvite(w http.ResponseWriter, r *http.Request) {
	invite, ok := s.publicFriendInvite(r.Context(), r.PathValue("token"))
	if !ok || invite.InviteStatus == "revoked" {
		writeError(w, http.StatusNotFound, "not_found", "专属邀请不存在或已失效")
		return
	}
	ranges, err := s.pollTimeRanges(r.Context(), invite.Poll.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	selections, err := s.friendSelectionsForInvite(r.Context(), invite.InviteID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"poll": ownedPollJSON(invite.Poll),
		"invite": map[string]any{
			"id": invite.InviteID, "displayName": invite.DisplayName, "status": invite.InviteStatus,
		},
		"ranges": rangesJSON(ranges), "selections": selectionsJSON(selections),
	})
}

func (s *Server) handlePublicPollInviteSelections(w http.ResponseWriter, r *http.Request) {
	token := r.PathValue("token")
	invite, ok := s.publicFriendInvite(r.Context(), token)
	if !ok || invite.InviteStatus == "revoked" {
		writeError(w, http.StatusNotFound, "not_found", "专属邀请不存在或已失效")
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "poll_friend_selection", security.SHA256(token), 60); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "选择服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "提交过于频繁，请稍后重试")
		return
	}
	var input struct {
		Selections []friendSelectionInput `json:"selections"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if len(input.Selections) < 1 || len(input.Selections) > maximumSelectionsPerFriend {
		writeError(w, http.StatusBadRequest, "invalid_request", "请选择 1–200 段时间")
		return
	}
	ranges, err := s.pollTimeRanges(r.Context(), invite.Poll.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if err := validateFriendSelections(input.Selections, ranges); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_selection", err.Error())
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var status, inviteStatus string
	var closes sql.NullTime
	var accountID string
	err = tx.QueryRowContext(r.Context(), `SELECT p.status, p.closes_at, p.account_id, i.status
      FROM poll_friend_invites i JOIN share_polls p ON p.id = i.poll_id
      WHERE i.id = ? AND i.access_token_hash = ? FOR UPDATE`, invite.InviteID, security.SHA256(token)).
		Scan(&status, &closes, &accountID, &inviteStatus)
	if err != nil || inviteStatus == "revoked" {
		writeError(w, http.StatusNotFound, "not_found", "专属邀请不存在或已失效")
		return
	}
	if !pollIsOpen(status, closes, time.Now().UTC()) {
		writeError(w, http.StatusConflict, "poll_closed", "活动已结束")
		return
	}
	if _, err = tx.ExecContext(r.Context(), "DELETE FROM poll_friend_selections WHERE invite_id = ?", invite.InviteID); err != nil {
		writeError(w, http.StatusInternalServerError, "selection_failed", "暂时无法保存选择")
		return
	}
	for _, selection := range input.Selections {
		id, idErr := security.RandomID()
		if idErr != nil {
			err = idErr
			break
		}
		_, err = tx.ExecContext(r.Context(), `INSERT INTO poll_friend_selections
        (id, invite_id, starts_at, ends_at) VALUES (?, ?, ?, ?)`, id, invite.InviteID,
			selection.StartsAt.UTC(), selection.EndsAt.UTC())
		if err != nil {
			break
		}
	}
	if err == nil {
		_, err = tx.ExecContext(r.Context(), `UPDATE poll_friend_invites SET status = 'submitted',
        submitted_at = UTC_TIMESTAMP(6) WHERE id = ?`, invite.InviteID)
	}
	if err == nil {
		_, err = tx.ExecContext(r.Context(), "UPDATE share_polls SET version = version + 1 WHERE id = ?", invite.Poll.ID)
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "selection_failed", "暂时无法保存选择")
		return
	}
	s.audit(r.Context(), "poll-invite:"+invite.InviteID, "poll.friend_selection.save", "share_poll", invite.Poll.ID, "allowed", "low")
	s.syncHub.publish(accountID)
	writeJSON(w, http.StatusOK, map[string]any{"saved": true, "selectionCount": len(input.Selections)})
}

func (s *Server) handleOwnedPollConfirm(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	var input struct {
		StartsAt        time.Time `json:"startsAt"`
		EndsAt          time.Time `json:"endsAt"`
		ExpectedVersion int64     `json:"expectedVersion"`
	}
	if err := decodeJSON(r, &input); err != nil || input.ExpectedVersion < 1 || !validSelectionInterval(input.StartsAt, input.EndsAt) {
		writeError(w, http.StatusBadRequest, "invalid_request", "确认时间无效")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var title, timezone, status string
	var closes sql.NullTime
	var version int64
	err = tx.QueryRowContext(r.Context(), `SELECT title, timezone, status, closes_at, version FROM share_polls
      WHERE id = ? AND account_id = ? FOR UPDATE`, r.PathValue("id"), identity.AccountID).
		Scan(&title, &timezone, &status, &closes, &version)
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "活动不存在")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if !pollIsOpen(status, closes, time.Now().UTC()) {
		writeError(w, http.StatusConflict, "poll_closed", "活动已结束")
		return
	}
	if version != input.ExpectedVersion {
		writeError(w, http.StatusConflict, "version_conflict", "活动结果已变化，请刷新后重试")
		return
	}
	var inside int
	err = tx.QueryRowContext(r.Context(), `SELECT COUNT(*) FROM share_slots WHERE poll_id = ?
      AND starts_at <= ? AND ends_at >= ?`, r.PathValue("id"), input.StartsAt.UTC(), input.EndsAt.UTC()).Scan(&inside)
	if err != nil || inside < 1 {
		writeError(w, http.StatusBadRequest, "invalid_selection", "确认时间不在设定范围内")
		return
	}
	_, err = tx.ExecContext(r.Context(), `UPDATE share_polls SET status = 'closed', selected_starts_at = ?,
      selected_ends_at = ?, version = version + 1 WHERE id = ? AND version = ?`, input.StartsAt.UTC(),
		input.EndsAt.UTC(), r.PathValue("id"), input.ExpectedVersion)
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "confirm_failed", "暂时无法确认时间")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "poll.confirm", "share_poll", r.PathValue("id"), "allowed", "medium")
	s.syncHub.publish(identity.AccountID)
	writeJSON(w, http.StatusOK, map[string]any{
		"pollId": r.PathValue("id"), "title": title, "timezone": timezone,
		"version": input.ExpectedVersion + 1,
		"selectedSlot": map[string]any{
			"id": "confirmed:" + r.PathValue("id"), "label": "", "startsAt": input.StartsAt.UTC(), "endsAt": input.EndsAt.UTC(),
		},
	})
}

func (s *Server) ownedPollByID(ctx context.Context, pollID, accountID string) (ownedPollRecord, error) {
	var poll ownedPollRecord
	err := s.db.QueryRowContext(ctx, `SELECT p.id, p.account_id, p.title, p.description, p.timezone,
      p.status, p.closes_at, COALESCE(p.selected_starts_at, selected.starts_at),
      COALESCE(p.selected_ends_at, selected.ends_at), p.version, p.created_at, p.updated_at
      FROM share_polls p LEFT JOIN share_slots selected ON selected.id = p.selected_slot_id
      WHERE p.id = ? AND p.account_id = ? LIMIT 1`, pollID, accountID).
		Scan(&poll.ID, &poll.AccountID, &poll.Title, &poll.Description, &poll.Timezone, &poll.Status,
			&poll.ClosesAt, &poll.SelectedStarts, &poll.SelectedEnds, &poll.Version, &poll.CreatedAt, &poll.UpdatedAt)
	return poll, err
}

func (s *Server) publicFriendInvite(ctx context.Context, token string) (publicFriendInviteRecord, bool) {
	if len(token) < 20 || len(token) > 200 || !strings.HasPrefix(token, "dli_") {
		return publicFriendInviteRecord{}, false
	}
	var invite publicFriendInviteRecord
	err := s.db.QueryRowContext(ctx, `SELECT i.id, i.display_name, i.status,
      p.id, p.account_id, p.title, p.description, p.timezone, p.status, p.closes_at,
      p.selected_starts_at, p.selected_ends_at, p.version, p.created_at, p.updated_at
      FROM poll_friend_invites i JOIN share_polls p ON p.id = i.poll_id
      WHERE i.access_token_hash = ? LIMIT 1`, security.SHA256(token)).
		Scan(&invite.InviteID, &invite.DisplayName, &invite.InviteStatus,
			&invite.Poll.ID, &invite.Poll.AccountID, &invite.Poll.Title, &invite.Poll.Description,
			&invite.Poll.Timezone, &invite.Poll.Status, &invite.Poll.ClosesAt, &invite.Poll.SelectedStarts,
			&invite.Poll.SelectedEnds, &invite.Poll.Version, &invite.Poll.CreatedAt, &invite.Poll.UpdatedAt)
	return invite, err == nil
}

func (s *Server) pollTimeRanges(ctx context.Context, pollID string) ([]pollTimeRange, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, label, starts_at, ends_at FROM share_slots
      WHERE poll_id = ? ORDER BY sort_order`, pollID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	ranges := make([]pollTimeRange, 0)
	for rows.Next() {
		var value pollTimeRange
		if err := rows.Scan(&value.ID, &value.Label, &value.StartsAt, &value.EndsAt); err != nil {
			return nil, err
		}
		ranges = append(ranges, value)
	}
	return ranges, rows.Err()
}

func (s *Server) friendSelectionsForPoll(ctx context.Context, pollID string) ([]pollFriendSelection, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT selection.id, selection.invite_id, selection.starts_at, selection.ends_at
      FROM poll_friend_selections selection JOIN poll_friend_invites invite ON invite.id = selection.invite_id
      WHERE invite.poll_id = ? AND invite.status = 'submitted' ORDER BY selection.starts_at, selection.ends_at`, pollID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanFriendSelections(rows)
}

func (s *Server) friendSelectionsForInvite(ctx context.Context, inviteID string) ([]pollFriendSelection, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT id, invite_id, starts_at, ends_at
      FROM poll_friend_selections WHERE invite_id = ? ORDER BY starts_at, ends_at`, inviteID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanFriendSelections(rows)
}

func scanFriendSelections(rows *sql.Rows) ([]pollFriendSelection, error) {
	values := make([]pollFriendSelection, 0)
	for rows.Next() {
		var value pollFriendSelection
		if err := rows.Scan(&value.ID, &value.InviteID, &value.StartsAt, &value.EndsAt); err != nil {
			return nil, err
		}
		values = append(values, value)
	}
	return values, rows.Err()
}

func validateFriendSelections(selections []friendSelectionInput, ranges []pollTimeRange) error {
	sorted := append([]friendSelectionInput(nil), selections...)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].StartsAt.Before(sorted[j].StartsAt) })
	for index, selection := range sorted {
		if !validSelectionInterval(selection.StartsAt, selection.EndsAt) {
			return errors.New("每段选择需为 5 分钟到 24 小时")
		}
		inside := false
		for _, allowed := range ranges {
			if !selection.StartsAt.Before(allowed.StartsAt) && !selection.EndsAt.After(allowed.EndsAt) {
				inside = true
				break
			}
		}
		if !inside {
			return errors.New("选择超出了活动设定的时间范围")
		}
		if index > 0 && sorted[index-1].EndsAt.After(selection.StartsAt) {
			return errors.New("选择的时间段不能重叠")
		}
	}
	return nil
}

func validatePollTimeRanges(ranges []pollSlotInput, closesAt *time.Time, now time.Time) error {
	sorted := append([]pollSlotInput(nil), ranges...)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].StartsAt.Before(sorted[j].StartsAt) })
	for index, value := range sorted {
		value.StartsAt = value.StartsAt.UTC()
		value.EndsAt = value.EndsAt.UTC()
		if !validSelectionInterval(value.StartsAt, value.EndsAt) || utf8.RuneCountInString(value.Label) > 120 {
			return errors.New("每个可选时间范围需为 5 分钟到 24 小时")
		}
		if !value.StartsAt.After(now.UTC()) {
			return errors.New("可选时间范围必须晚于当前时间")
		}
		if index > 0 && sorted[index-1].EndsAt.UTC().After(value.StartsAt) {
			return errors.New("可选时间范围不能重叠")
		}
	}
	if closesAt != nil {
		deadline := closesAt.UTC()
		if !deadline.After(now.UTC()) {
			return errors.New("截止时间必须晚于当前时间")
		}
		if len(sorted) > 0 && !deadline.Before(sorted[0].StartsAt.UTC()) {
			return errors.New("截止时间必须早于可选时间范围")
		}
	}
	return nil
}

func validSelectionInterval(startsAt, endsAt time.Time) bool {
	if startsAt.IsZero() || endsAt.IsZero() || !endsAt.After(startsAt) {
		return false
	}
	duration := endsAt.Sub(startsAt)
	return duration >= minimumSelectionDuration && duration <= maximumSelectionDuration &&
		startsAt.UTC().Unix()%300 == 0 && endsAt.UTC().Unix()%300 == 0
}

func aggregateFriendSelections(selections []pollFriendSelection) []map[string]any {
	type point struct {
		At    time.Time
		Delta int
	}
	points := make([]point, 0, len(selections)*2)
	for _, selection := range selections {
		points = append(points, point{At: selection.StartsAt.UTC(), Delta: 1}, point{At: selection.EndsAt.UTC(), Delta: -1})
	}
	sort.Slice(points, func(i, j int) bool { return points[i].At.Before(points[j].At) })
	type segment struct {
		StartsAt time.Time
		EndsAt   time.Time
		Count    int
	}
	segments := make([]segment, 0)
	count := 0
	for index := 0; index < len(points); {
		at := points[index].At
		for index < len(points) && points[index].At.Equal(at) {
			count += points[index].Delta
			index++
		}
		if index >= len(points) || count <= 0 || !points[index].At.After(at) {
			continue
		}
		end := points[index].At
		if len(segments) > 0 && segments[len(segments)-1].Count == count && segments[len(segments)-1].EndsAt.Equal(at) {
			segments[len(segments)-1].EndsAt = end
		} else {
			segments = append(segments, segment{StartsAt: at, EndsAt: end, Count: count})
		}
	}
	sort.SliceStable(segments, func(i, j int) bool {
		if segments[i].Count != segments[j].Count {
			return segments[i].Count > segments[j].Count
		}
		return segments[i].StartsAt.Before(segments[j].StartsAt)
	})
	if len(segments) > 100 {
		segments = segments[:100]
	}
	result := make([]map[string]any, 0, len(segments))
	for _, value := range segments {
		result = append(result, map[string]any{
			"startsAt": value.StartsAt, "endsAt": value.EndsAt, "peopleCount": value.Count,
		})
	}
	return result
}

func ownedPollJSON(poll ownedPollRecord) map[string]any {
	status := poll.Status
	if status == "open" && poll.ClosesAt.Valid && !poll.ClosesAt.Time.After(time.Now().UTC()) {
		status = "expired"
	}
	return map[string]any{
		"id": poll.ID, "title": poll.Title, "description": poll.Description, "timezone": poll.Timezone,
		"status": status, "closesAt": nullableTime(poll.ClosesAt), "version": poll.Version,
		"selectedStartsAt": nullableTime(poll.SelectedStarts), "selectedEndsAt": nullableTime(poll.SelectedEnds),
		"createdAt": poll.CreatedAt, "updatedAt": poll.UpdatedAt,
	}
}

func rangesJSON(ranges []pollTimeRange) []map[string]any {
	result := make([]map[string]any, 0, len(ranges))
	for _, value := range ranges {
		result = append(result, map[string]any{
			"id": value.ID, "label": value.Label, "startsAt": value.StartsAt, "endsAt": value.EndsAt,
		})
	}
	return result
}

func selectionJSON(selection pollFriendSelection) map[string]any {
	return map[string]any{
		"id": selection.ID, "startsAt": selection.StartsAt, "endsAt": selection.EndsAt,
	}
}

func selectionsJSON(selections []pollFriendSelection) []map[string]any {
	result := make([]map[string]any, 0, len(selections))
	for _, selection := range selections {
		result = append(result, selectionJSON(selection))
	}
	return result
}

func pollIsOpen(status string, closes sql.NullTime, now time.Time) bool {
	return status == "open" && (!closes.Valid || closes.Time.After(now.UTC()))
}
