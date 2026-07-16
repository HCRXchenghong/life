package httpapi

import "sync"

type syncHub struct {
	mu      sync.Mutex
	nextID  uint64
	clients map[string]map[uint64]syncClient
}

type syncClient struct {
	sessionID string
	channel   chan syncEvent
}

type syncEvent struct {
	Name   string
	Reason string
}

func newSyncHub() *syncHub {
	return &syncHub{clients: make(map[string]map[uint64]syncClient)}
}

func (h *syncHub) subscribe(accountID, sessionID string) (<-chan syncEvent, func()) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.nextID++
	id := h.nextID
	channel := make(chan syncEvent, 1)
	if h.clients[accountID] == nil {
		h.clients[accountID] = make(map[uint64]syncClient)
	}
	h.clients[accountID][id] = syncClient{sessionID: sessionID, channel: channel}
	return channel, func() {
		h.mu.Lock()
		defer h.mu.Unlock()
		delete(h.clients[accountID], id)
		if len(h.clients[accountID]) == 0 {
			delete(h.clients, accountID)
		}
	}
}

func (h *syncHub) publish(accountID string) {
	h.send(accountID, syncEvent{Name: "changes"})
}

func (h *syncHub) revoke(accountID, reason string) {
	h.send(accountID, syncEvent{Name: "session_revoked", Reason: safeRevocationReason(reason)})
}

func (h *syncHub) revokeOtherSessions(accountID, currentSessionID, reason string) {
	h.sendExcept(accountID, currentSessionID, syncEvent{Name: "session_revoked", Reason: safeRevocationReason(reason)})
}

func (h *syncHub) revokeSession(accountID, sessionID, reason string) {
	h.sendOnly(accountID, sessionID, syncEvent{Name: "session_revoked", Reason: safeRevocationReason(reason)})
}

func (h *syncHub) send(accountID string, event syncEvent) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, client := range h.clients[accountID] {
		enqueueSyncEvent(client.channel, event)
	}
}

func (h *syncHub) sendExcept(accountID, excludedSessionID string, event syncEvent) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, client := range h.clients[accountID] {
		if client.sessionID != excludedSessionID {
			enqueueSyncEvent(client.channel, event)
		}
	}
}

func (h *syncHub) sendOnly(accountID, sessionID string, event syncEvent) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, client := range h.clients[accountID] {
		if client.sessionID == sessionID {
			enqueueSyncEvent(client.channel, event)
		}
	}
}

func enqueueSyncEvent(channel chan syncEvent, event syncEvent) {
	if event.Name == "session_revoked" {
		select {
		case <-channel:
		default:
		}
	}
	select {
	case channel <- event:
	default:
	}
}

func safeRevocationReason(reason string) string {
	switch reason {
	case "account_disabled", "credentials_changed":
		return reason
	default:
		return "session_revoked"
	}
}
