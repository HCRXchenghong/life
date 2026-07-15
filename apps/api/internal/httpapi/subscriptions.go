package httpapi

import (
	"context"
	"database/sql"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

const (
	maximumAIQuotaUnits   = 10_000_000
	aiUsageReservationTTL = 10 * time.Minute
)

type publicAIPlanLimit struct {
	Plan         string    `json:"plan"`
	WeeklyUnits  int       `json:"weeklyUnits"`
	MonthlyUnits int       `json:"monthlyUnits"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

type publicAISubscription struct {
	Plan      string    `json:"plan"`
	CardType  string    `json:"cardType"`
	StartsAt  time.Time `json:"startsAt"`
	ExpiresAt time.Time `json:"expiresAt"`
	Active    bool      `json:"active"`
}

type publicAIEntitlement struct {
	Active          bool       `json:"active"`
	Plan            string     `json:"plan,omitempty"`
	CardType        string     `json:"cardType,omitempty"`
	StartsAt        *time.Time `json:"startsAt,omitempty"`
	ExpiresAt       *time.Time `json:"expiresAt,omitempty"`
	WeeklyUsed      int        `json:"weeklyUsed"`
	WeeklyLimit     *int       `json:"weeklyLimit"`
	WeeklyResetsAt  time.Time  `json:"weeklyResetsAt"`
	MonthlyUsed     int        `json:"monthlyUsed"`
	MonthlyLimit    *int       `json:"monthlyLimit"`
	MonthlyResetsAt time.Time  `json:"monthlyResetsAt"`
	SupportedModes  []string   `json:"supportedModes"`
}

type aiUsageReservation struct {
	ID string
}

type aiEntitlementError struct {
	Code    string
	Message string
}

func (e *aiEntitlementError) Error() string { return e.Message }

func (s *Server) handleAdminAIPlanLimits(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		limits, err := s.listAIPlanLimits(r.Context())
		if err != nil {
			writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"plans": limits})
		return
	}
	if !s.requireSameOrigin(w, r) {
		return
	}
	var input struct {
		Plus struct {
			WeeklyUnits  int `json:"weeklyUnits"`
			MonthlyUnits int `json:"monthlyUnits"`
		} `json:"plus"`
		Pro struct {
			WeeklyUnits  int `json:"weeklyUnits"`
			MonthlyUnits int `json:"monthlyUnits"`
		} `json:"pro"`
	}
	if err := decodeJSON(r, &input); err != nil ||
		!validAIPlanLimit(input.Plus.WeeklyUnits, input.Plus.MonthlyUnits) ||
		!validAIPlanLimit(input.Pro.WeeklyUnits, input.Pro.MonthlyUnits) ||
		(input.Plus.WeeklyUnits > 0 && input.Pro.WeeklyUnits > 0 && input.Pro.WeeklyUnits < input.Plus.WeeklyUnits) ||
		(input.Plus.MonthlyUnits > 0 && input.Pro.MonthlyUnits > 0 && input.Pro.MonthlyUnits < input.Plus.MonthlyUnits) {
		writeError(w, http.StatusBadRequest, "invalid_request", "套餐额度无效，Pro 额度不能低于 Plus")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	for _, plan := range []struct {
		name         string
		weeklyUnits  int
		monthlyUnits int
	}{{"plus", input.Plus.WeeklyUnits, input.Plus.MonthlyUnits}, {"pro", input.Pro.WeeklyUnits, input.Pro.MonthlyUnits}} {
		_, err = tx.ExecContext(r.Context(), `INSERT INTO ai_plan_limits
          (plan, weekly_units, monthly_units, updated_by_admin_id) VALUES (?, ?, ?, ?)
          ON DUPLICATE KEY UPDATE weekly_units = VALUES(weekly_units), monthly_units = VALUES(monthly_units),
          updated_by_admin_id = VALUES(updated_by_admin_id)`, plan.name, plan.weeklyUnits, plan.monthlyUnits, identity.ID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "plan_update_failed", "套餐额度保存失败")
			return
		}
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "plan_update_failed", "套餐额度保存失败")
		return
	}
	s.audit(r.Context(), identity.Actor, "ai_plan_limits.update", "ai_plan", "", "allowed", "high")
	limits, _ := s.listAIPlanLimits(r.Context())
	writeJSON(w, http.StatusOK, map[string]any{"plans": limits})
}

func (s *Server) handleAdminAppSubscription(w http.ResponseWriter, r *http.Request) {
	if !s.requireSameOrigin(w, r) {
		return
	}
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	var input struct {
		AccountID string `json:"accountId"`
		Action    string `json:"action"`
		Plan      string `json:"plan,omitempty"`
		CardType  string `json:"cardType,omitempty"`
	}
	if err := decodeJSON(r, &input); err != nil || input.AccountID == "" {
		writeError(w, http.StatusBadRequest, "invalid_request", "套餐请求无效")
		return
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	defer func() { _ = tx.Rollback() }()
	var accountID string
	if err := tx.QueryRowContext(r.Context(), "SELECT id FROM app_accounts WHERE id = ? FOR UPDATE", input.AccountID).Scan(&accountID); err != nil {
		writeError(w, http.StatusNotFound, "not_found", "App 账号不存在")
		return
	}
	switch input.Action {
	case "revoke":
		if _, err = tx.ExecContext(r.Context(), "DELETE FROM app_ai_subscriptions WHERE account_id = ?", accountID); err == nil {
			_, err = tx.ExecContext(r.Context(), "UPDATE ai_gateway_tokens SET revoked_at = UTC_TIMESTAMP(6) WHERE account_id = ? AND revoked_at IS NULL", accountID)
		}
	case "grant":
		if !validAIPlan(input.Plan) {
			err = errors.New("套餐类型无效")
			break
		}
		if input.Plan != "max" {
			var weekly, monthly int
			if scanErr := tx.QueryRowContext(r.Context(), "SELECT weekly_units, monthly_units FROM ai_plan_limits WHERE plan = ?", input.Plan).Scan(&weekly, &monthly); scanErr != nil || weekly < 1 || monthly < 1 {
				err = errors.New("请先在设置中配置该套餐的周额度和月额度")
				break
			}
		}
		now := time.Now().UTC()
		base := now
		var currentPlan string
		var currentExpiry time.Time
		scanErr := tx.QueryRowContext(r.Context(), "SELECT plan, expires_at FROM app_ai_subscriptions WHERE account_id = ?", accountID).Scan(&currentPlan, &currentExpiry)
		if scanErr == nil && currentPlan == input.Plan && currentExpiry.After(now) {
			base = currentExpiry
		} else if scanErr != nil && !errors.Is(scanErr, sql.ErrNoRows) {
			err = scanErr
			break
		}
		expiresAt, durationOK := addSubscriptionDuration(base, input.CardType)
		if !durationOK {
			err = errors.New("卡类型无效")
			break
		}
		_, err = tx.ExecContext(r.Context(), `INSERT INTO app_ai_subscriptions
          (account_id, plan, card_type, starts_at, expires_at, granted_by_admin_id)
          VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE plan = VALUES(plan),
          card_type = VALUES(card_type), starts_at = VALUES(starts_at), expires_at = VALUES(expires_at),
          granted_by_admin_id = VALUES(granted_by_admin_id)`, accountID, input.Plan, input.CardType, now, expiresAt, identity.ID)
	default:
		err = errors.New("套餐操作无效")
	}
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	if err := tx.Commit(); err != nil {
		writeError(w, http.StatusInternalServerError, "subscription_update_failed", "套餐保存失败")
		return
	}
	s.audit(r.Context(), identity.Actor, "app_subscription."+input.Action, "app_account", accountID, "allowed", "high")
	subscription, err := s.loadPublicAISubscription(r.Context(), accountID)
	if input.Action == "revoke" || errors.Is(err, sql.ErrNoRows) {
		writeJSON(w, http.StatusOK, map[string]any{"subscription": nil})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"subscription": subscription})
}

func (s *Server) handleAppAIEntitlement(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireApp(w, r)
	if !ok {
		return
	}
	entitlement, err := s.loadAIEntitlement(r.Context(), identity.AccountID, time.Now().UTC())
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "database_unavailable", "数据库暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"entitlement": entitlement})
}

func (s *Server) listAIPlanLimits(ctx context.Context) ([]publicAIPlanLimit, error) {
	rows, err := s.db.QueryContext(ctx, "SELECT plan, weekly_units, monthly_units, updated_at FROM ai_plan_limits ORDER BY FIELD(plan, 'plus', 'pro')")
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	limits := make([]publicAIPlanLimit, 0, 2)
	for rows.Next() {
		var limit publicAIPlanLimit
		if err := rows.Scan(&limit.Plan, &limit.WeeklyUnits, &limit.MonthlyUnits, &limit.UpdatedAt); err != nil {
			return nil, err
		}
		limits = append(limits, limit)
	}
	return limits, rows.Err()
}

func (s *Server) loadPublicAISubscription(ctx context.Context, accountID string) (*publicAISubscription, error) {
	var subscription publicAISubscription
	err := s.db.QueryRowContext(ctx, `SELECT plan, card_type, starts_at, expires_at,
      expires_at > UTC_TIMESTAMP(6) FROM app_ai_subscriptions WHERE account_id = ?`, accountID).
		Scan(&subscription.Plan, &subscription.CardType, &subscription.StartsAt, &subscription.ExpiresAt, &subscription.Active)
	if err != nil {
		return nil, err
	}
	return &subscription, nil
}

func (s *Server) loadAIEntitlement(ctx context.Context, accountID string, now time.Time) (publicAIEntitlement, error) {
	weekStart, weekReset, monthStart, monthReset := aiQuotaWindows(now)
	entitlement := publicAIEntitlement{
		WeeklyResetsAt: weekReset, MonthlyResetsAt: monthReset,
		SupportedModes: []string{"local_ai", "ssh_agent"},
	}
	var startsAt, expiresAt time.Time
	err := s.db.QueryRowContext(ctx, `SELECT plan, card_type, starts_at, expires_at
      FROM app_ai_subscriptions WHERE account_id = ? LIMIT 1`, accountID).
		Scan(&entitlement.Plan, &entitlement.CardType, &startsAt, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) {
		return entitlement, nil
	}
	if err != nil {
		return publicAIEntitlement{}, err
	}
	entitlement.StartsAt, entitlement.ExpiresAt = &startsAt, &expiresAt
	entitlement.Active = expiresAt.After(now)
	if entitlement.Plan != "max" {
		var weekly, monthly int
		if err := s.db.QueryRowContext(ctx, "SELECT weekly_units, monthly_units FROM ai_plan_limits WHERE plan = ?", entitlement.Plan).Scan(&weekly, &monthly); err != nil {
			return publicAIEntitlement{}, err
		}
		entitlement.WeeklyLimit, entitlement.MonthlyLimit = &weekly, &monthly
	}
	if err := s.db.QueryRowContext(ctx, `SELECT
      COALESCE(SUM(CASE WHEN created_at >= ? THEN units ELSE 0 END), 0),
      COALESCE(SUM(CASE WHEN created_at >= ? THEN units ELSE 0 END), 0)
		FROM ai_usage_events WHERE account_id = ? AND
		(status = 'charged' OR (status = 'reserved' AND created_at >= ?))`,
		weekStart, monthStart, accountID, now.Add(-aiUsageReservationTTL)).
		Scan(&entitlement.WeeklyUsed, &entitlement.MonthlyUsed); err != nil {
		return publicAIEntitlement{}, err
	}
	return entitlement, nil
}

func (s *Server) reserveAIUsage(ctx context.Context, accountID, mode, kind string, units int) (aiUsageReservation, error) {
	if !validAIMode(mode) || (kind != "responses" && kind != "image") || units < 1 || units > 100 {
		return aiUsageReservation{}, &aiEntitlementError{Code: "invalid_usage", Message: "AI 用量请求无效"}
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return aiUsageReservation{}, err
	}
	defer func() { _ = tx.Rollback() }()
	var plan string
	var expiresAt time.Time
	err = tx.QueryRowContext(ctx, `SELECT plan, expires_at FROM app_ai_subscriptions
      WHERE account_id = ? FOR UPDATE`, accountID).Scan(&plan, &expiresAt)
	if errors.Is(err, sql.ErrNoRows) || !expiresAt.After(time.Now().UTC()) {
		return aiUsageReservation{}, &aiEntitlementError{Code: "subscription_required", Message: "AI 套餐未开通或已到期"}
	}
	if err != nil {
		return aiUsageReservation{}, err
	}
	if plan != "max" {
		var weeklyLimit, monthlyLimit int
		if err := tx.QueryRowContext(ctx, "SELECT weekly_units, monthly_units FROM ai_plan_limits WHERE plan = ?", plan).Scan(&weeklyLimit, &monthlyLimit); err != nil {
			return aiUsageReservation{}, err
		}
		if weeklyLimit < 1 || monthlyLimit < 1 {
			return aiUsageReservation{}, &aiEntitlementError{Code: "plan_not_configured", Message: "该套餐额度尚未配置"}
		}
		weekStart, _, monthStart, _ := aiQuotaWindows(time.Now().UTC())
		var weeklyUsed, monthlyUsed int
		if err := tx.QueryRowContext(ctx, `SELECT
          COALESCE(SUM(CASE WHEN created_at >= ? THEN units ELSE 0 END), 0),
          COALESCE(SUM(CASE WHEN created_at >= ? THEN units ELSE 0 END), 0)
			FROM ai_usage_events WHERE account_id = ? AND
			(status = 'charged' OR (status = 'reserved' AND created_at >= ?))`,
			weekStart, monthStart, accountID, time.Now().UTC().Add(-aiUsageReservationTTL)).
			Scan(&weeklyUsed, &monthlyUsed); err != nil {
			return aiUsageReservation{}, err
		}
		if weeklyUsed+units > weeklyLimit {
			return aiUsageReservation{}, &aiEntitlementError{Code: "weekly_quota_exceeded", Message: "本周 AI 额度已用完"}
		}
		if monthlyUsed+units > monthlyLimit {
			return aiUsageReservation{}, &aiEntitlementError{Code: "monthly_quota_exceeded", Message: "本月 AI 额度已用完"}
		}
	}
	id, err := security.RandomID()
	if err != nil {
		return aiUsageReservation{}, err
	}
	if _, err := tx.ExecContext(ctx, `INSERT INTO ai_usage_events
      (id, account_id, mode, kind, units, status) VALUES (?, ?, ?, ?, ?, 'reserved')`,
		id, accountID, mode, kind, units); err != nil {
		return aiUsageReservation{}, err
	}
	if err := tx.Commit(); err != nil {
		return aiUsageReservation{}, err
	}
	return aiUsageReservation{ID: id}, nil
}

func (s *Server) finishAIUsage(ctx context.Context, reservation aiUsageReservation, charged bool) {
	if reservation.ID == "" {
		return
	}
	status := "released"
	if charged {
		status = "charged"
	}
	_, _ = s.db.ExecContext(ctx, `UPDATE ai_usage_events SET status = ?, finalized_at = UTC_TIMESTAMP(6)
      WHERE id = ? AND status = 'reserved'`, status, reservation.ID)
}

func writeAIEntitlementError(w http.ResponseWriter, err error) bool {
	var entitlementError *aiEntitlementError
	if !errors.As(err, &entitlementError) {
		return false
	}
	writeError(w, http.StatusPaymentRequired, entitlementError.Code, entitlementError.Message)
	return true
}

func validAIPlanLimit(weekly, monthly int) bool {
	return weekly >= 0 && monthly >= 0 && weekly <= maximumAIQuotaUnits && monthly <= maximumAIQuotaUnits &&
		((weekly == 0 && monthly == 0) || (weekly > 0 && monthly >= weekly))
}

func validAIPlan(plan string) bool { return plan == "plus" || plan == "pro" || plan == "max" }

func validAIMode(mode string) bool { return mode == "local_ai" || mode == "ssh_agent" }

func addSubscriptionDuration(base time.Time, cardType string) (time.Time, bool) {
	switch strings.ToLower(cardType) {
	case "week":
		return base.AddDate(0, 0, 7), true
	case "month":
		return base.AddDate(0, 1, 0), true
	case "quarter":
		return base.AddDate(0, 3, 0), true
	case "year":
		return base.AddDate(1, 0, 0), true
	default:
		return time.Time{}, false
	}
}

func aiQuotaWindows(now time.Time) (time.Time, time.Time, time.Time, time.Time) {
	now = now.UTC()
	weekday := int(now.Weekday())
	if weekday == 0 {
		weekday = 7
	}
	weekStart := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -(weekday - 1))
	monthStart := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	return weekStart, weekStart.AddDate(0, 0, 7), monthStart, monthStart.AddDate(0, 1, 0)
}
