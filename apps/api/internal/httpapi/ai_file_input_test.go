package httpapi

import (
	"encoding/base64"
	"strings"
	"testing"
)

func TestValidateAssistantResponseInputAcceptsBoundedBase64File(t *testing.T) {
	t.Parallel()
	payload := "data:application/pdf;base64," + base64.StdEncoding.EncodeToString([]byte("%PDF"))
	err := validateAssistantResponseInput([]any{map[string]any{
		"role": "user",
		"content": []any{
			map[string]any{"type": "input_file", "filename": "真实资料.pdf", "file_data": payload, "detail": "auto"},
			map[string]any{"type": "input_text", "text": "总结文件"},
		},
	}})
	if err != nil {
		t.Fatalf("valid file input rejected: %v", err)
	}
}

func TestValidateAssistantResponseInputRejectsURLsAndOversizedFiles(t *testing.T) {
	t.Parallel()
	urlInput := []any{map[string]any{
		"role": "user",
		"content": []any{
			map[string]any{
				"type": "input_file", "filename": "x.pdf",
				"file_data": "data:application/pdf;base64," + base64.StdEncoding.EncodeToString([]byte("%PDF")),
				"file_url":  "https://example.com/x.pdf",
			},
			map[string]any{"type": "input_text", "text": "读取"},
		},
	}}
	if validateAssistantResponseInput(urlInput) == nil {
		t.Fatal("external file URL was accepted")
	}

	mismatchedInput := []any{map[string]any{
		"role": "user",
		"content": []any{
			map[string]any{
				"type": "input_file", "filename": "fake.pdf",
				"file_data": "data:application/pdf;base64," + base64.StdEncoding.EncodeToString([]byte("not a PDF")),
			},
			map[string]any{"type": "input_text", "text": "读取"},
		},
	}}
	if validateAssistantResponseInput(mismatchedInput) == nil {
		t.Fatal("file with mismatched content was accepted")
	}

	oversized := strings.Repeat("A", base64.StdEncoding.EncodedLen(maximumAssistantInputFile+1))
	sizeInput := []any{map[string]any{
		"role": "user",
		"content": []any{
			map[string]any{
				"type": "input_file", "filename": "x.pdf",
				"file_data": "data:application/pdf;base64," + oversized,
			},
			map[string]any{"type": "input_text", "text": "读取"},
		},
	}}
	if validateAssistantResponseInput(sizeInput) == nil {
		t.Fatal("oversized file was accepted")
	}
}

func TestValidateAssistantResponseInputAcceptsBoundedBase64Image(t *testing.T) {
	t.Parallel()
	image := []byte{0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00}
	payload := "data:image/png;base64," + base64.StdEncoding.EncodeToString(image)
	err := validateAssistantResponseInput([]any{map[string]any{
		"role": "user",
		"content": []any{
			map[string]any{"type": "input_image", "image_url": payload, "detail": "auto"},
			map[string]any{"type": "input_text", "text": "说明图片内容"},
		},
	}})
	if err != nil {
		t.Fatalf("valid image input rejected: %v", err)
	}
}

func TestValidateAssistantResponseInputRejectsRemoteAndMismatchedImages(t *testing.T) {
	t.Parallel()
	remote := []any{map[string]any{
		"role": "user",
		"content": []any{
			map[string]any{"type": "input_image", "image_url": "https://example.com/private.png"},
			map[string]any{"type": "input_text", "text": "说明图片"},
		},
	}}
	if validateAssistantResponseInput(remote) == nil {
		t.Fatal("remote image URL was accepted")
	}

	mismatched := []any{map[string]any{
		"role": "user",
		"content": []any{
			map[string]any{
				"type":      "input_image",
				"image_url": "data:image/png;base64," + base64.StdEncoding.EncodeToString([]byte("not a PNG")),
			},
			map[string]any{"type": "input_text", "text": "说明图片"},
		},
	}}
	if validateAssistantResponseInput(mismatched) == nil {
		t.Fatal("image with mismatched content was accepted")
	}
}
