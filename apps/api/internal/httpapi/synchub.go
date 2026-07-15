package httpapi

import "sync"

type syncHub struct {
	mu      sync.Mutex
	nextID  uint64
	clients map[string]map[uint64]chan syncEvent
}

type syncEvent struct {
	Name   string
	Reason string
}

func newSyncHub() *syncHub {
	return &syncHub{clients: make(map[string]map[uint64]chan syncEvent)}
}

func (h *syncHub) subscribe(accountID string) (<-chan syncEvent, func()) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.nextID++
	id := h.nextID
	channel := make(chan syncEvent, 1)
	if h.clients[accountID] == nil {
		h.clients[accountID] = make(map[uint64]chan syncEvent)
	}
	h.clients[accountID][id] = channel
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
	switch reason {
	case "account_disabled", "credentials_changed":
	default:
		reason = "session_revoked"
	}
	h.send(accountID, syncEvent{Name: "session_revoked", Reason: reason})
}

func (h *syncHub) send(accountID string, event syncEvent) {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, channel := range h.clients[accountID] {
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
}
