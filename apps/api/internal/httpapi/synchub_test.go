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
	case <-accountA:
	case <-time.After(time.Second):
		t.Fatal("account A did not receive its update")
	}
	select {
	case <-accountB:
		t.Fatal("account B received account A's update")
	case <-time.After(20 * time.Millisecond):
	}
}
