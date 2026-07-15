package httpapi

import "testing"

func TestNormalizeAIBaseURLAddsV1OnlyAtOriginRoot(t *testing.T) {
	t.Parallel()
	root, err := normalizeAIBaseURL("https://api.example.com")
	if err != nil || root != "https://api.example.com/v1" {
		t.Fatalf("root URL = %q, %v", root, err)
	}
	existing, err := normalizeAIBaseURL("https://api.example.com/openai/v1/")
	if err != nil || existing != "https://api.example.com/openai/v1" {
		t.Fatalf("existing URL = %q, %v", existing, err)
	}
}

func TestSelectProviderModelsPrefersResponsesAndImageModels(t *testing.T) {
	t.Parallel()
	text, image, ok := selectProviderModels([]string{
		"text-embedding-3-large", "gpt-4.1", "gpt-image-1", "gpt-5.4", "gpt-image-1.5",
	})
	if !ok || text != "gpt-5.4" || image != "gpt-image-1.5" {
		t.Fatalf("selected %q, %q, %v", text, image, ok)
	}
}

func TestSelectProviderModelsAllowsTextOnlyProviders(t *testing.T) {
	t.Parallel()
	text, image, ok := selectProviderModels([]string{"claude-sonnet-4", "text-embedding-3-large"})
	if !ok || text != "claude-sonnet-4" || image != "" {
		t.Fatalf("text-only provider selected %q, %q, %v", text, image, ok)
	}
}

func TestProviderModelEntriesAcceptsCompatibleShapes(t *testing.T) {
	t.Parallel()
	for _, raw := range []string{
		`{"data":[{"id":"gpt-5.4"}]}`,
		`{"models":["gpt-5.4"]}`,
		`[{"id":"gpt-5.4"}]`,
	} {
		models, err := providerModelEntries([]byte(raw))
		if err != nil || len(models) != 1 || models[0] != "gpt-5.4" {
			t.Fatalf("providerModelEntries(%s) = %#v, %v", raw, models, err)
		}
	}
}

func TestReasoningEffortsMatchAppContract(t *testing.T) {
	t.Parallel()
	for _, effort := range []string{"low", "medium", "high", "xhigh"} {
		if !validAIReasoningEffort(effort) {
			t.Fatalf("%s should be supported", effort)
		}
	}
	for _, effort := range []string{"", "minimal", "max", "ultra"} {
		if validAIReasoningEffort(effort) {
			t.Fatalf("%s should be rejected", effort)
		}
	}
}
