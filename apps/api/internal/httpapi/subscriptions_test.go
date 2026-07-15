package httpapi

import (
	"testing"
	"time"
)

func TestAIPlanLimitValidation(t *testing.T) {
	t.Parallel()
	for _, test := range []struct {
		weekly, monthly int64
		valid           bool
	}{
		{0, 0, true},
		{100, 400, true},
		{400, 100, false},
		{0, 100, false},
		{-1, 100, false},
		{100, maximumAIQuotaTokens + 1, false},
	} {
		if actual := validAIPlanLimit(test.weekly, test.monthly); actual != test.valid {
			t.Fatalf("validAIPlanLimit(%d, %d) = %v, want %v", test.weekly, test.monthly, actual, test.valid)
		}
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

func TestAIQuotaWindowsResetOnUTCMondayAndMonth(t *testing.T) {
	t.Parallel()
	now := time.Date(2026, time.July, 15, 9, 30, 0, 0, time.FixedZone("CST", 8*60*60))
	weekStart, weekReset, monthStart, monthReset := aiQuotaWindows(now)
	if want := time.Date(2026, time.July, 13, 0, 0, 0, 0, time.UTC); !weekStart.Equal(want) {
		t.Fatalf("week start = %v, want %v", weekStart, want)
	}
	if !weekReset.Equal(time.Date(2026, time.July, 20, 0, 0, 0, 0, time.UTC)) {
		t.Fatalf("week reset = %v", weekReset)
	}
	if !monthStart.Equal(time.Date(2026, time.July, 1, 0, 0, 0, 0, time.UTC)) ||
		!monthReset.Equal(time.Date(2026, time.August, 1, 0, 0, 0, 0, time.UTC)) {
		t.Fatalf("month window = %v - %v", monthStart, monthReset)
	}
}
