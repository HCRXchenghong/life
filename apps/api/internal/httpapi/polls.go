package httpapi

import (
	"database/sql"
	"errors"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

type pollSlotInput struct {
	Label    string    `json:"label"`
	StartsAt time.Time `json:"startsAt"`
	EndsAt   time.Time `json:"endsAt"`
}

func (s *Server) handlePolls(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		rows, err := s.db.QueryContext(r.Context(), `SELECT p.id, p.title, p.timezone, p.status, p.closes_at,
        p.version, p.created_at, p.updated_at,
        (SELECT COUNT(*) FROM share_slots slot_count WHERE slot_count.poll_id = p.id),
        ((SELECT COUNT(*) FROM poll_friend_invites friend_count
          WHERE friend_count.poll_id = p.id AND friend_count.status <> 'revoked') +
         (SELECT COUNT(*) FROM poll_participants legacy_count WHERE legacy_count.poll_id = p.id)),
        selected.id, selected.label, COALESCE(p.selected_starts_at, selected.starts_at),
        COALESCE(p.selected_ends_at, selected.ends_at)
        FROM share_polls p
        LEFT JOIN share_slots selected ON selected.id = p.selected_slot_id AND selected.poll_id = p.id
        WHERE p.account_id = ? ORDER BY p.created_at DESC LIMIT 100`, identity.AccountID)
		if err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		defer rows.Close()
		polls := make([]map[string]any, 0)
		for rows.Next() {
			var id, title, timezone, status string
			var closes, selectedStarts, selectedEnds sql.NullTime
			var selectedID, selectedLabel sql.NullString
			var version, candidateCount, participantCount int64
			var created, updated time.Time
			if err := rows.Scan(&id, &title, &timezone, &status, &closes, &version, &created, &updated,
				&candidateCount, &participantCount, &selectedID, &selectedLabel, &selectedStarts, &selectedEnds); err != nil {
				writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
				return
			}
			var selectedSlot any
			if selectedStarts.Valid && selectedEnds.Valid {
				resolvedID := selectedID.String
				if resolvedID == "" {
					resolvedID = "confirmed:" + id
				}
				selectedSlot = map[string]any{"id": resolvedID, "label": selectedLabel.String,
					"startsAt": selectedStarts.Time, "endsAt": selectedEnds.Time}
			}
			polls = append(polls, map[string]any{"id": id, "title": title, "timezone": timezone,
				"status": status, "closesAt": nullableTime(closes), "selectedSlot": selectedSlot,
				"version": version, "candidateCount": candidateCount, "participantCount": participantCount,
				"createdAt": created, "updatedAt": updated})
		}
		if rows.Err() != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"polls": polls})
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "poll_create", identity.AccountID, 60); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "投票服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "创建投票过于频繁")
		return
	}
	var input struct {
		Title            string          `json:"title"`
		Description      string          `json:"description"`
		Timezone         string          `json:"timezone"`
		ClosesAt         *time.Time      `json:"closesAt"`
		Slots            []pollSlotInput `json:"slots"`
		ExclusiveInvites bool            `json:"exclusiveInvites"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	input.Title = strings.TrimSpace(input.Title)
	input.Description = strings.TrimSpace(input.Description)
	if len(input.Title) == 0 || len(input.Title) > 160 || len(input.Description) > 2000 || len(input.Slots) < 1 || len(input.Slots) > 30 {
		writeError(w, http.StatusBadRequest, "invalid_request", "投票内容无效")
		return
	}
	if _, err := time.LoadLocation(input.Timezone); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "时区必须是有效的 IANA 时区")
		return
	}
	for index, slot := range input.Slots {
		input.Slots[index].StartsAt = slot.StartsAt.UTC()
		input.Slots[index].EndsAt = slot.EndsAt.UTC()
	}
	if err := validatePollTimeRanges(input.Slots, input.ClosesAt, time.Now().UTC()); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	pollID, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "poll_create_failed", "暂时无法创建投票")
		return
	}
	publicToken, err := security.RandomToken("dlp_")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "poll_create_failed", "暂时无法创建投票")
		return
	}
	manageToken, err := security.RandomToken("dlm_")
	if err != nil {
		writeError(w, http.StatusInternalServerError, "poll_create_failed", "暂时无法创建投票")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	_, err = tx.ExecContext(r.Context(), `INSERT INTO share_polls
      (id, account_id, title, description, timezone, public_token_hash, manage_token_hash, status, closes_at, version)
      VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?, 1)`, pollID, identity.AccountID, input.Title,
		input.Description, input.Timezone, security.SHA256(publicToken), security.SHA256(manageToken), input.ClosesAt)
	if err == nil {
		for index, slot := range input.Slots {
			slotID, idErr := security.RandomID()
			if idErr != nil {
				err = idErr
				break
			}
			_, err = tx.ExecContext(r.Context(), `INSERT INTO share_slots
          (id, poll_id, label, starts_at, ends_at, sort_order) VALUES (?, ?, ?, ?, ?, ?)`,
				slotID, pollID, strings.TrimSpace(slot.Label), slot.StartsAt, slot.EndsAt, index)
			if err != nil {
				break
			}
		}
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "poll_create_failed", "暂时无法创建投票")
		return
	}
	s.audit(r.Context(), "app:"+identity.AccountID, "poll.create", "share_poll", pollID, "allowed", "low")
	if input.ExclusiveInvites {
		writeJSON(w, http.StatusCreated, map[string]any{"poll": map[string]any{
			"id": pollID, "status": "open", "version": 1,
		}})
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"poll": map[string]any{
		"id": pollID, "publicToken": publicToken, "manageToken": manageToken,
		"inviteUrl": s.cfg.PublicOrigin + "/poll/" + publicToken, "status": "open", "version": 1,
	}})
}

type publicPoll struct {
	ID             string
	Title          string
	Description    string
	Timezone       string
	Status         string
	ClosesAt       sql.NullTime
	SelectedSlotID sql.NullString
	Version        int64
}

func (s *Server) handlePoll(w http.ResponseWriter, r *http.Request) {
	poll, ok := s.pollByPublicToken(r, r.PathValue("token"))
	if !ok {
		writeError(w, http.StatusNotFound, "not_found", "投票不存在")
		return
	}
	slots, participants, votes, err := s.pollDetails(r, poll.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"poll": map[string]any{
		"id": poll.ID, "title": poll.Title, "description": poll.Description, "timezone": poll.Timezone,
		"status": poll.Status, "closesAt": nullableTime(poll.ClosesAt), "selectedSlotId": nullableString(poll.SelectedSlotID), "version": poll.Version,
	}, "slots": slots, "participants": participants, "votes": votes})
}

func (s *Server) handlePollVotes(w http.ResponseWriter, r *http.Request) {
	poll, ok := s.pollByPublicToken(r, r.PathValue("token"))
	if !ok {
		writeError(w, http.StatusNotFound, "not_found", "投票不存在")
		return
	}
	if poll.Status != "open" || (poll.ClosesAt.Valid && poll.ClosesAt.Time.Before(time.Now().UTC())) {
		writeError(w, http.StatusConflict, "poll_closed", "投票已结束")
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "poll_vote", poll.ID, 60); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "投票服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "提交过于频繁，请稍后重试")
		return
	}
	var input struct {
		DisplayName string `json:"displayName"`
		EditToken   string `json:"editToken,omitempty"`
		Votes       []struct {
			SlotID   string `json:"slotId"`
			Response string `json:"response"`
		} `json:"votes"`
	}
	if err := decodeJSON(r, &input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	input.DisplayName = strings.TrimSpace(input.DisplayName)
	if len(input.DisplayName) == 0 || len(input.DisplayName) > 80 || len(input.Votes) == 0 || len(input.Votes) > 100 {
		writeError(w, http.StatusBadRequest, "invalid_request", "投票内容无效")
		return
	}
	validSlots := make(map[string]bool)
	rows, err := s.db.QueryContext(r.Context(), "SELECT id FROM share_slots WHERE poll_id = ?", poll.ID)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer rows.Close()
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		validSlots[id] = true
	}
	if rows.Err() != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	seen := make(map[string]bool)
	for _, vote := range input.Votes {
		if !validSlots[vote.SlotID] || seen[vote.SlotID] || (vote.Response != "yes" && vote.Response != "maybe" && vote.Response != "no") {
			writeError(w, http.StatusBadRequest, "invalid_request", "投票选择无效")
			return
		}
		seen[vote.SlotID] = true
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var lockedStatus string
	var lockedCloses sql.NullTime
	if err := tx.QueryRowContext(r.Context(), "SELECT status, closes_at FROM share_polls WHERE id = ? FOR UPDATE", poll.ID).
		Scan(&lockedStatus, &lockedCloses); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	if lockedStatus != "open" || (lockedCloses.Valid && lockedCloses.Time.Before(time.Now().UTC())) {
		writeError(w, http.StatusConflict, "poll_closed", "投票已结束")
		return
	}
	participantID := ""
	editToken := input.EditToken
	created := false
	if editToken != "" {
		err := tx.QueryRowContext(r.Context(), "SELECT id FROM poll_participants WHERE poll_id = ? AND edit_token_hash = ?", poll.ID, security.SHA256(editToken)).Scan(&participantID)
		if err != nil {
			writeError(w, http.StatusForbidden, "invalid_edit_token", "编辑凭据无效")
			return
		}
		if _, err := tx.ExecContext(r.Context(), "UPDATE poll_participants SET display_name = ? WHERE id = ?", input.DisplayName, participantID); err != nil {
			writeError(w, http.StatusInternalServerError, "vote_failed", "暂时无法保存投票")
			return
		}
	} else {
		created = true
		participantID, err = security.RandomID()
		if err == nil {
			editToken, err = security.RandomToken("dlv_")
		}
		if err == nil {
			_, err = tx.ExecContext(r.Context(), `INSERT INTO poll_participants
        (id, poll_id, display_name, edit_token_hash) VALUES (?, ?, ?, ?)`, participantID, poll.ID, input.DisplayName, security.SHA256(editToken))
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "vote_failed", "暂时无法保存投票")
			return
		}
	}
	if _, err := tx.ExecContext(r.Context(), "DELETE FROM poll_votes WHERE participant_id = ?", participantID); err != nil {
		writeError(w, http.StatusInternalServerError, "vote_failed", "暂时无法保存投票")
		return
	}
	for _, vote := range input.Votes {
		if _, err := tx.ExecContext(r.Context(), `INSERT INTO poll_votes
        (participant_id, slot_id, response) VALUES (?, ?, ?)`, participantID, vote.SlotID, vote.Response); err != nil {
			writeError(w, http.StatusInternalServerError, "vote_failed", "暂时无法保存投票")
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "vote_failed", "暂时无法保存投票")
		return
	}
	status := http.StatusOK
	if created {
		status = http.StatusCreated
	}
	writeJSON(w, status, map[string]any{"participant": map[string]any{"id": participantID, "displayName": input.DisplayName}, "editToken": editToken, "version": poll.Version})
}

func (s *Server) handlePollFinalize(w http.ResponseWriter, r *http.Request) {
	poll, ok := s.pollByPublicToken(r, r.PathValue("token"))
	if !ok {
		writeError(w, http.StatusNotFound, "not_found", "投票不存在")
		return
	}
	if retry, err := s.consumeRateLimit(r.Context(), r, "poll_finalize", poll.ID, 20); err != nil {
		writeError(w, http.StatusServiceUnavailable, "rate_limit_unavailable", "投票服务暂时不可用")
		return
	} else if retry > 0 {
		writeError(w, http.StatusTooManyRequests, "rate_limited", "操作过于频繁，请稍后重试")
		return
	}
	var input struct {
		ManageToken     string `json:"manageToken"`
		SlotID          string `json:"slotId"`
		ExpectedVersion int64  `json:"expectedVersion"`
	}
	if err := decodeJSON(r, &input); err != nil || input.ExpectedVersion < 1 {
		writeError(w, http.StatusBadRequest, "invalid_request", "请求无效")
		return
	}
	if input.ExpectedVersion != poll.Version {
		writeError(w, http.StatusConflict, "version_conflict", "投票已变化，请刷新后重试")
		return
	}
	var valid int
	_ = s.db.QueryRowContext(r.Context(), "SELECT COUNT(*) FROM share_polls WHERE id = ? AND manage_token_hash = ?", poll.ID, security.SHA256(input.ManageToken)).Scan(&valid)
	if valid != 1 {
		writeError(w, http.StatusForbidden, "invalid_manage_token", "管理凭据无效")
		return
	}
	var label string
	var starts, ends time.Time
	err := s.db.QueryRowContext(r.Context(), "SELECT label, starts_at, ends_at FROM share_slots WHERE id = ? AND poll_id = ?", input.SlotID, poll.ID).Scan(&label, &starts, &ends)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "选中的时间不属于该投票")
		return
	}
	result, err := s.db.ExecContext(r.Context(), `UPDATE share_polls SET status = 'closed', selected_slot_id = ?,
      version = version + 1 WHERE id = ? AND version = ?`, input.SlotID, poll.ID, input.ExpectedVersion)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "finalize_failed", "暂时无法结束投票")
		return
	}
	if changed, _ := result.RowsAffected(); changed != 1 {
		writeError(w, http.StatusConflict, "version_conflict", "投票已变化，请刷新后重试")
		return
	}
	s.audit(r.Context(), "poll-manager:"+poll.ID, "poll.finalize", "share_poll", poll.ID, "allowed", "medium")
	writeJSON(w, http.StatusOK, map[string]any{"pollId": poll.ID, "version": input.ExpectedVersion + 1,
		"selectedSlot": map[string]any{"id": input.SlotID, "label": label, "startsAt": starts, "endsAt": ends}})
}

func (s *Server) pollByPublicToken(r *http.Request, token string) (publicPoll, bool) {
	if len(token) < 20 || len(token) > 200 {
		return publicPoll{}, false
	}
	var poll publicPoll
	err := s.db.QueryRowContext(r.Context(), `SELECT id, title, description, timezone, status, closes_at,
      selected_slot_id, version FROM share_polls WHERE public_token_hash = ? LIMIT 1`, security.SHA256(token)).
		Scan(&poll.ID, &poll.Title, &poll.Description, &poll.Timezone, &poll.Status, &poll.ClosesAt, &poll.SelectedSlotID, &poll.Version)
	return poll, err == nil
}

func (s *Server) pollDetails(r *http.Request, pollID string) ([]map[string]any, []map[string]any, []map[string]any, error) {
	slotRows, err := s.db.QueryContext(r.Context(), "SELECT id, label, starts_at, ends_at FROM share_slots WHERE poll_id = ? ORDER BY sort_order", pollID)
	if err != nil {
		return nil, nil, nil, err
	}
	defer slotRows.Close()
	slots := make([]map[string]any, 0)
	for slotRows.Next() {
		var id, label string
		var starts, ends time.Time
		if err := slotRows.Scan(&id, &label, &starts, &ends); err != nil {
			return nil, nil, nil, err
		}
		slots = append(slots, map[string]any{"id": id, "label": label, "startsAt": starts, "endsAt": ends})
	}
	if err := slotRows.Err(); err != nil {
		return nil, nil, nil, err
	}
	participantRows, err := s.db.QueryContext(r.Context(), "SELECT id, display_name FROM poll_participants WHERE poll_id = ? ORDER BY created_at", pollID)
	if err != nil {
		return nil, nil, nil, err
	}
	defer participantRows.Close()
	participants := make([]map[string]any, 0)
	for participantRows.Next() {
		var id, name string
		if err := participantRows.Scan(&id, &name); err != nil {
			return nil, nil, nil, err
		}
		participants = append(participants, map[string]any{"id": id, "displayName": name})
	}
	if err := participantRows.Err(); err != nil {
		return nil, nil, nil, err
	}
	voteRows, err := s.db.QueryContext(r.Context(), `SELECT v.participant_id, v.slot_id, v.response
		FROM poll_votes v JOIN poll_participants p ON p.id = v.participant_id
		WHERE p.poll_id = ? ORDER BY p.created_at, v.slot_id`, pollID)
	if err != nil {
		return nil, nil, nil, err
	}
	defer voteRows.Close()
	votes := make([]map[string]any, 0)
	for voteRows.Next() {
		var participantID, slotID, response string
		if err := voteRows.Scan(&participantID, &slotID, &response); err != nil {
			return nil, nil, nil, err
		}
		votes = append(votes, map[string]any{"participantId": participantID, "slotId": slotID, "response": response})
	}
	if err := voteRows.Err(); err != nil {
		return nil, nil, nil, err
	}
	return slots, participants, votes, nil
}

func nullableString(value sql.NullString) any {
	if value.Valid {
		return value.String
	}
	return nil
}

var _ = strconv.IntSize
var _ = errors.Is
