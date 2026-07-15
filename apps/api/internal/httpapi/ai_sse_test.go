package httpapi

import (
	"strings"
	"testing"
)

func TestDecodeProviderSSEExtractsCompletedResponse(t *testing.T) {
	t.Parallel()
	stream := strings.Join([]string{
		"event: response.created",
		`data: {"type":"response.created","response":{"id":"resp_1","output":[]}}`,
		"",
		"event: response.completed",
		`data: {"type":"response.completed","response":{"id":"resp_1","status":"completed","output":[]}}`,
		"",
	}, "\n")
	result, err := decodeProviderSSE(strings.NewReader(stream), 1<<20)
	if err != nil {
		t.Fatal(err)
	}
	if result["id"] != "resp_1" || result["status"] != "completed" {
		t.Fatalf("unexpected response: %#v", result)
	}
}

func TestDecodeProviderSSERejectsFailedAndOversizedStreams(t *testing.T) {
	t.Parallel()
	failed := "event: response.failed\ndata: {\"type\":\"response.failed\"}\n\n"
	if _, err := decodeProviderSSE(strings.NewReader(failed), 1<<20); err == nil {
		t.Fatal("failed Responses event accepted")
	}
	if _, err := decodeProviderSSE(strings.NewReader(strings.Repeat("x", 200)), 64); err == nil {
		t.Fatal("oversized stream accepted")
	}
}
