package httpapi

import (
	"testing"
	"time"
)

func TestInvitationDurations(t *testing.T) {
	t.Parallel()
	cases := map[string]time.Duration{
		"day": 24 * time.Hour, "week": 7 * 24 * time.Hour, "month": 30 * 24 * time.Hour,
	}
	for input, want := range cases {
		got, ok := invitationDuration(input)
		if !ok || got != want {
			t.Fatalf("invitationDuration(%q) = %v, %v", input, got, ok)
		}
	}
	if _, ok := invitationDuration("year"); ok {
		t.Fatal("unsupported duration accepted")
	}
}

func TestInvitationCodeHashIsScopedAndStable(t *testing.T) {
	t.Parallel()
	key := []byte("01234567890123456789012345678901")
	first := invitationCodeHash(key, "invite-a", " abcd2345 ")
	if first != invitationCodeHash(key, "invite-a", "ABCD2345") {
		t.Fatal("normalized invitation code hash changed")
	}
	if first == invitationCodeHash(key, "invite-b", "ABCD2345") {
		t.Fatal("invitation code hash was not invitation-scoped")
	}
}

func TestInvitationTokenValidation(t *testing.T) {
	t.Parallel()
	if !validInvitationToken("dli_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV") {
		t.Fatal("valid invitation token rejected")
	}
	if validInvitationToken("dli_too-short") || validInvitationToken("dli_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO/QRSTUV") {
		t.Fatal("invalid invitation token accepted")
	}
}
