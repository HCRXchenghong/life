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

func TestSelectProviderModelsRequiresImageCapability(t *testing.T) {
	t.Parallel()
	_, _, ok := selectProviderModels([]string{"gpt-5.4", "text-embedding-3-large"})
	if ok {
		t.Fatal("provider without image model must not be accepted")
	}
}
