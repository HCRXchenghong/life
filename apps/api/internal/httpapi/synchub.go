package httpapi

import "sync"

type syncHub struct {
	mu      sync.Mutex
	nextID  uint64
	clients map[string]map[uint64]chan struct{}
}

func newSyncHub() *syncHub {
	return &syncHub{clients: make(map[string]map[uint64]chan struct{})}
}

func (h *syncHub) subscribe(accountID string) (<-chan struct{}, func()) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.nextID++
	id := h.nextID
	channel := make(chan struct{}, 1)
	if h.clients[accountID] == nil {
		h.clients[accountID] = make(map[uint64]chan struct{})
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
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, channel := range h.clients[accountID] {
		select {
		case channel <- struct{}{}:
		default:
		}
	}
}
