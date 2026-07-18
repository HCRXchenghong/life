package httpapi

import (
	"testing"
	"time"
)

func TestValidatePollTimeRanges(t *testing.T) {
	now := time.Date(2026, 7, 18, 1, 0, 0, 0, time.UTC)
	deadline := now.Add(time.Hour)
	valid := []pollSlotInput{
		{StartsAt: now.Add(2 * time.Hour), EndsAt: now.Add(4 * time.Hour)},
		{StartsAt: now.Add(24 * time.Hour), EndsAt: now.Add(26 * time.Hour)},
	}
	if err := validatePollTimeRanges(valid, &deadline, now); err != nil {
		t.Fatalf("valid ranges rejected: %v", err)
	}

	overlapping := append([]pollSlotInput(nil), valid...)
	overlapping[1] = pollSlotInput{StartsAt: now.Add(3 * time.Hour), EndsAt: now.Add(5 * time.Hour)}
	if err := validatePollTimeRanges(overlapping, &deadline, now); err == nil {
		t.Fatal("overlapping ranges should be rejected")
	}

	unaligned := append([]pollSlotInput(nil), valid...)
	unaligned[0].StartsAt = unaligned[0].StartsAt.Add(time.Minute)
	if err := validatePollTimeRanges(unaligned, &deadline, now); err == nil {
		t.Fatal("ranges not aligned to five minutes should be rejected")
	}
}

func TestValidateFriendSelections(t *testing.T) {
	start := time.Date(2026, 7, 19, 4, 0, 0, 0, time.UTC)
	ranges := []pollTimeRange{{StartsAt: start, EndsAt: start.Add(4 * time.Hour)}}
	valid := []friendSelectionInput{
		{StartsAt: start.Add(30 * time.Minute), EndsAt: start.Add(time.Hour)},
		{StartsAt: start.Add(2 * time.Hour), EndsAt: start.Add(3 * time.Hour)},
	}
	if err := validateFriendSelections(valid, ranges); err != nil {
		t.Fatalf("valid selections rejected: %v", err)
	}

	outOfRange := []friendSelectionInput{{StartsAt: start.Add(-time.Hour), EndsAt: start}}
	if err := validateFriendSelections(outOfRange, ranges); err == nil {
		t.Fatal("selection outside configured range should be rejected")
	}

	overlapping := []friendSelectionInput{
		{StartsAt: start, EndsAt: start.Add(2 * time.Hour)},
		{StartsAt: start.Add(time.Hour), EndsAt: start.Add(3 * time.Hour)},
	}
	if err := validateFriendSelections(overlapping, ranges); err == nil {
		t.Fatal("overlapping selections should be rejected")
	}
}

func TestAggregateFriendSelections(t *testing.T) {
	start := time.Date(2026, 7, 19, 4, 0, 0, 0, time.UTC)
	values := []pollFriendSelection{
		{InviteID: "a", StartsAt: start, EndsAt: start.Add(2 * time.Hour)},
		{InviteID: "b", StartsAt: start.Add(time.Hour), EndsAt: start.Add(3 * time.Hour)},
	}
	result := aggregateFriendSelections(values)
	if len(result) != 3 {
		t.Fatalf("expected three availability segments, got %d", len(result))
	}
	if result[0]["peopleCount"] != 2 || result[0]["startsAt"] != start.Add(time.Hour) || result[0]["endsAt"] != start.Add(2*time.Hour) {
		t.Fatalf("best segment is incorrect: %#v", result[0])
	}
}
