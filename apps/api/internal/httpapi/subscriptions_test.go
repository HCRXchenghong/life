package httpapi

import (
	"bytes"
	"encoding/json"
	"testing"
	"time"
)

func TestAIPlanLimitValidation(t *testing.T) {
	t.Parallel()
	for _, test := range []struct {
		monthly int64
		valid   bool
	}{
		{0, true},
		{400, true},
		{-1, false},
		{maximumAIQuotaTokens + 1, false},
	} {
		if actual := validAIPlanLimit(test.monthly); actual != test.valid {
			t.Fatalf("validAIPlanLimit(%d) = %v, want %v", test.monthly, actual, test.valid)
		}
	}
}

func TestPublicAIEntitlementExposesMonthlyQuotaOnly(t *testing.T) {
	t.Parallel()
	payload, err := json.Marshal(publicAIEntitlement{
		MonthlyUsed:     42,
		MonthlyResetsAt: time.Date(2026, time.August, 1, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(bytes.ToLower(payload), []byte("week")) {
		t.Fatalf("weekly quota leaked into App contract: %s", payload)
	}
	if !bytes.Contains(payload, []byte(`"monthlyUsed":42`)) ||
		!bytes.Contains(payload, []byte(`"monthlyResetsAt"`)) {
		t.Fatalf("monthly quota missing from App contract: %s", payload)
	}
}

func TestSubscriptionDurationsUseCalendarCards(t *testing.T) {
	t.Parallel()
	base := time.Date(2026, time.January, 31, 8, 30, 0, 0, time.UTC)
	week, ok := addSubscriptionDuration(base, "week")
	if !ok || !week.Equal(time.Date(2026, time.February, 7, 8, 30, 0, 0, time.UTC)) {
		t.Fatalf("week card = %v, %v", week, ok)
	}
	quarter, ok := addSubscriptionDuration(base, "quarter")
	if !ok || !quarter.Equal(base.AddDate(0, 3, 0)) {
		t.Fatalf("quarter card = %v, %v", quarter, ok)
	}
	if _, ok := addSubscriptionDuration(base, "lifetime"); ok {
		t.Fatal("unsupported card type must fail")
	}
}

func TestAIQuotaWindowResetsAtNextUTCMonth(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, time.July, 15, 9, 30, 0, 0, time.FixedZone("CST", 8*60*60))
	monthStart, monthReset := aiQuotaWindow(now)
	if !monthStart.Equal(time.Date(2026, time.July, 1, 0, 0, 0, 0, time.UTC)) ||
		!monthReset.Equal(time.Date(2026, time.August, 1, 0, 0, 0, 0, time.UTC)) {
		t.Fatalf("month window = %v - %v", monthStart, monthReset)
	}
}
