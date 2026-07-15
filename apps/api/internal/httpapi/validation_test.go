package httpapi

import (
	"encoding/base64"
	"testing"
)

func TestValidatePublicHTTPSBaseURL(t *testing.T) {
	if value, err := validatePublicHTTPSBaseURL("https://api.example.com/v1/"); err != nil || value != "https://api.example.com/v1" {
		t.Fatalf("valid provider URL rejected: %q %v", value, err)
	}
	for _, value := range []string{
		"http://api.example.com/v1",
		"https://localhost/v1",
		"https://127.0.0.1/v1",
		"https://user:password@api.example.com/v1",
		"https://api.example.com/v1?token=secret",
	} {
		if _, err := validatePublicHTTPSBaseURL(value); err == nil {
			t.Fatalf("unsafe provider URL accepted: %s", value)
		}
	}
}

func TestStrictFunctionToolRequiresClosedObjectSchema(t *testing.T) {
	valid := map[string]any{
		"type": "function", "name": "schedule_create", "strict": true,
		"parameters": map[string]any{"type": "object", "properties": map[string]any{}, "additionalProperties": false},
	}
	if !strictFunctionTool(valid) {
		t.Fatal("valid strict tool rejected")
	}
	valid["strict"] = false
	if strictFunctionTool(valid) {
		t.Fatal("non-strict tool accepted")
	}
	valid["strict"] = true
	valid["parameters"] = map[string]any{
		"type": "object", "additionalProperties": false,
		"properties": map[string]any{"nested": map[string]any{"type": "object", "properties": map[string]any{}}},
	}
	if strictFunctionTool(valid) {
		t.Fatal("nested open object schema accepted")
	}
}

func TestParseImageDataAcceptsOnlyBoundedPNG(t *testing.T) {
	png := append([]byte("\x89PNG\r\n\x1a\n"), []byte("test")...)
	if decoded, err := parseImageData(base64.StdEncoding.EncodeToString(png)); err != nil || string(decoded) != string(png) {
		t.Fatal("valid PNG rejected")
	}
	if _, err := parseImageData(base64.StdEncoding.EncodeToString([]byte("not a png"))); err == nil {
		t.Fatal("non-PNG image accepted")
	}
}

func TestSyncIdentifiers(t *testing.T) {
	if !validUUIDLike("550e8400-e29b-41d4-a716-446655440000") {
		t.Fatal("valid UUID rejected")
	}
	for _, value := range []string{"", "550e8400-e29b-41d4-a716-44665544000z", "550e8400e29b41d4a716446655440000"} {
		if validUUIDLike(value) {
			t.Fatalf("invalid UUID accepted: %s", value)
		}
	}
}
