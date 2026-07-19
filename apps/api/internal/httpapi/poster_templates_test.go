package httpapi

import (
	"encoding/json"
	"testing"
)

func TestBuiltInPosterTemplateIsValid(t *testing.T) {
	for _, definition := range builtInPosterDefinitions {
		canonical, schema, err := validatePosterTemplateSchema(json.RawMessage(definition.schema))
		if err != nil {
			t.Fatalf("%s: %v", definition.code, err)
		}
		if len(canonical) == 0 || schema.Canvas.Width != 1080 || schema.Canvas.Height != 1440 {
			t.Fatalf("%s has an unexpected canvas", definition.code)
		}
	}
}

func TestPosterTemplateRejectsExecutableOrDuplicateQRContent(t *testing.T) {
	raw := json.RawMessage(`{"schemaVersion":1,"canvas":{"width":1080,"height":1440,"backgroundColor":"#FFFFFF"},"layers":[{"type":"html","binding":"inviteUrl","x":0,"y":0,"width":100,"height":100},{"type":"qr","binding":"inviteUrl","x":100,"y":100,"width":200,"height":200},{"type":"qr","binding":"inviteUrl","x":400,"y":100,"width":200,"height":200}]}`)
	if _, _, err := validatePosterTemplateSchema(raw); err == nil {
		t.Fatal("executable and duplicate QR layers must be rejected")
	}
}
