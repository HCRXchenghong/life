package httpapi

import (
	"testing"
	"time"
)

func TestSyncHubPublishesOnlyInsideAccountScope(t *testing.T) {
	t.Parallel()
	hub := newSyncHub()
	accountA, unsubscribeA := hub.subscribe("account-a")
	defer unsubscribeA()
	accountB, unsubscribeB := hub.subscribe("account-b")
	defer unsubscribeB()

	hub.publish("account-a")
	select {
	case event := <-accountA:
		if event.Name != "changes" {
			t.Fatalf("account A received event %q", event.Name)
		}
	case <-time.After(time.Second):
		t.Fatal("account A did not receive its update")
	}
	select {
	case <-accountB:
		t.Fatal("account B received account A's update")
	case <-time.After(20 * time.Millisecond):
	}
}

func TestSyncHubBroadcastsSafeSessionRevocationReason(t *testing.T) {
	t.Parallel()
	hub := newSyncHub()
	account, unsubscribe := hub.subscribe("account-a")
	defer unsubscribe()

	hub.publish("account-a")
	hub.revoke("account-a", "account_disabled")
	event := <-account
	if event.Name != "session_revoked" || event.Reason != "account_disabled" {
		t.Fatalf("unexpected revocation event: %#v", event)
	}

	hub.revoke("account-a", "untrusted\r\ndata")
	event = <-account
	if event.Reason != "session_revoked" {
		t.Fatalf("unsafe revocation reason was not replaced: %#v", event)
	}
}
