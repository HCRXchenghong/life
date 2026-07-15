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
	for _, encoded := range []string{
		base64.StdEncoding.EncodeToString(png),
		base64.RawStdEncoding.EncodeToString(png),
		"data:image/png;base64," + base64.StdEncoding.EncodeToString(png),
	} {
		if decoded, err := parseImageData(encoded); err != nil || string(decoded) != string(png) {
			t.Fatalf("valid PNG rejected: %v", err)
		}
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

func TestAuditLocalizationAndPaginationBounds(t *testing.T) {
	if got := boundedPositiveInt("2", 1, 1, 100); got != 2 {
		t.Fatalf("valid page changed: %d", got)
	}
	if got := boundedPositiveInt("1000", 20, 10, 100); got != 100 {
		t.Fatalf("page size was not capped: %d", got)
	}
	if auditActionLabel("admin.login") != "管理员登录" || auditOutcomeLabel("denied") != "已拒绝" {
		t.Fatal("known audit values were not localized")
	}
	if auditActorLabel("app:550e8400-e29b-41d4-a716-446655440000") != "App 用户" {
		t.Fatal("app actor identity leaked or was not localized")
	}
}

func TestServerMetricNormalization(t *testing.T) {
	for _, test := range []struct {
		os, platform, want string
	}{
		{os: "windows", want: "Windows"},
		{os: "darwin", want: "macOS"},
		{os: "linux", platform: "ubuntu", want: "Ubuntu"},
	} {
		if _, label := normalizeSystem(test.os, test.platform); label != test.want {
			t.Fatalf("system label = %q, want %q", label, test.want)
		}
	}
	if normalizedPercent(123.44) != 100 || normalizedPercent(-1) != 0 || normalizedPercent(55.56) != 55.6 {
		t.Fatal("metric percentages were not safely normalized")
	}
}
