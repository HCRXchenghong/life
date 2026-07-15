package httpapi

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestExtractProviderTokenUsageUsesTotalWithoutDoubleCountingDetails(t *testing.T) {
	t.Parallel()
	payload, err := decodeProviderEvent([]byte(`{
      "usage": {
        "input_tokens": 120,
        "input_tokens_details": {"cached_tokens": 40},
        "output_tokens": 80,
        "output_tokens_details": {"reasoning_tokens": 30},
        "total_tokens": 200
      }
    }`))
	if err != nil {
		t.Fatal(err)
	}
	usage, ok := extractProviderTokenUsage(payload)
	if !ok || usage.TotalTokens != 200 || usage.CachedInputTokens != 40 || usage.ReasoningTokens != 30 {
		t.Fatalf("usage = %#v, %v", usage, ok)
	}
}

func TestExtractProviderTokenUsageRejectsMissingActualCounts(t *testing.T) {
	t.Parallel()
	if _, ok := extractProviderTokenUsage(map[string]any{"usage": map[string]any{
		"input_tokens": json.Number("10"),
	}}); ok {
		t.Fatal("partial usage must not be charged")
	}
}

func TestCopyProviderResponseCapturesCompletedSSEUsage(t *testing.T) {
	t.Parallel()
	stream := "event: response.completed\n" +
		"data: {\"type\":\"response.completed\",\"response\":{\"usage\":{\"input_tokens\":12,\"output_tokens\":8,\"total_tokens\":20}}}\n\n"
	var output strings.Builder
	usage, err := copyProviderResponse(&output, strings.NewReader(stream), "text/event-stream", 1<<20)
	if err != nil || output.String() != stream || usage == nil || usage.TotalTokens != 20 {
		t.Fatalf("usage = %#v, output = %q, err = %v", usage, output.String(), err)
	}
}
