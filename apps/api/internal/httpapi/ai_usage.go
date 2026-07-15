package httpapi

import (
	"bytes"
	"encoding/json"
	"math"
)

const maximumProviderTokenCount = int64(1_000_000_000_000)

type providerTokenUsage struct {
	InputTokens       int64
	OutputTokens      int64
	TotalTokens       int64
	CachedInputTokens int64
	ReasoningTokens   int64
}

func extractProviderTokenUsage(payload map[string]any) (providerTokenUsage, bool) {
	usage, _ := payload["usage"].(map[string]any)
	if usage == nil {
		if response, ok := payload["response"].(map[string]any); ok {
			usage, _ = response["usage"].(map[string]any)
		}
	}
	if usage == nil {
		return providerTokenUsage{}, false
	}
	input, inputOK := tokenInteger(usage["input_tokens"])
	output, outputOK := tokenInteger(usage["output_tokens"])
	total, totalOK := tokenInteger(usage["total_tokens"])
	if !inputOK || !outputOK {
		return providerTokenUsage{}, false
	}
	if !totalOK || total < input+output {
		total = input + output
	}
	if total < 1 || total > maximumProviderTokenCount {
		return providerTokenUsage{}, false
	}
	cached := int64(0)
	if details, ok := usage["input_tokens_details"].(map[string]any); ok {
		if value, valid := tokenInteger(details["cached_tokens"]); valid && value <= input {
			cached = value
		}
	}
	reasoning := int64(0)
	if details, ok := usage["output_tokens_details"].(map[string]any); ok {
		if value, valid := tokenInteger(details["reasoning_tokens"]); valid && value <= output {
			reasoning = value
		}
	}
	return providerTokenUsage{
		InputTokens: input, OutputTokens: output, TotalTokens: total,
		CachedInputTokens: cached, ReasoningTokens: reasoning,
	}, true
}

func decodeProviderEvent(raw []byte) (map[string]any, error) {
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.UseNumber()
	var payload map[string]any
	err := decoder.Decode(&payload)
	return payload, err
}

func tokenInteger(value any) (int64, bool) {
	var number int64
	switch typed := value.(type) {
	case json.Number:
		parsed, err := typed.Int64()
		if err != nil {
			return 0, false
		}
		number = parsed
	case float64:
		if math.Trunc(typed) != typed || typed > float64(maximumProviderTokenCount) {
			return 0, false
		}
		number = int64(typed)
	case int:
		number = int64(typed)
	case int64:
		number = typed
	default:
		return 0, false
	}
	return number, number >= 0 && number <= maximumProviderTokenCount
}

func estimateResponseReservation(requestBytes int, body map[string]any) int64 {
	output := int64(128_000)
	if value, ok := tokenInteger(body["max_output_tokens"]); ok && value > 0 {
		output = value
	}
	// A UTF-8 JSON request cannot contain more text tokens than bytes. The hold is
	// deliberately conservative and is replaced with provider-reported usage.
	reservation := int64(requestBytes) + output
	if reservation < 1_000 {
		return 1_000
	}
	if reservation > 16_000_000 {
		return 16_000_000
	}
	return reservation
}

func estimateImageReservation() int64 { return 2_000_000 }
