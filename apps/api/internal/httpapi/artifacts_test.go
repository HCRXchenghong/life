package httpapi

import (
	"archive/zip"
	"bytes"
	"encoding/xml"
	"io"
	"strings"
	"testing"
)

func TestGenerateOfficeArtifactsAreValidIsolatedPackages(t *testing.T) {
	t.Parallel()
	cases := []artifactRequest{
		{Kind: "docx", Title: "周计划", Paragraphs: []string{"第一段", "第二段 & <安全>"}},
		{Kind: "xlsx", Title: "预算", Sheets: []artifactSheet{{Name: "预算", Rows: [][]string{{"项目", "金额"}, {"交通", "120"}}}}},
		{Kind: "pptx", Title: "项目汇报", Slides: []artifactSlide{{Title: "目标", Bullets: []string{"清晰", "可靠"}}}},
	}
	for _, input := range cases {
		input := input
		t.Run(input.Kind, func(t *testing.T) {
			artifact, err := generateOfficeArtifact(input)
			if err != nil {
				t.Fatal(err)
			}
			if artifact.Extension != input.Kind || len(artifact.Content) == 0 || len(artifact.Content) > maximumArtifactBytes {
				t.Fatalf("invalid artifact metadata: %#v", artifact)
			}
			reader, err := zip.NewReader(bytes.NewReader(artifact.Content), int64(len(artifact.Content)))
			if err != nil {
				t.Fatalf("invalid OOXML zip: %v", err)
			}
			entries := make(map[string]string, len(reader.File))
			for _, file := range reader.File {
				stream, err := file.Open()
				if err != nil {
					t.Fatal(err)
				}
				content, err := io.ReadAll(stream)
				_ = stream.Close()
				if err != nil {
					t.Fatal(err)
				}
				entries[file.Name] = string(content)
			}
			if entries["[Content_Types].xml"] == "" || entries["_rels/.rels"] == "" {
				t.Fatal("required OOXML package entries are missing")
			}
			for name, content := range entries {
				if strings.Contains(name, "../") || strings.Contains(content, "/var/") || strings.Contains(content, "/Users/") {
					t.Fatalf("artifact leaked a server path in %s", name)
				}
				if strings.HasSuffix(name, ".xml") || strings.HasSuffix(name, ".rels") {
					decoder := xml.NewDecoder(strings.NewReader(content))
					for {
						_, err := decoder.Token()
						if err == io.EOF {
							break
						}
						if err != nil {
							t.Fatalf("invalid XML in %s: %v", name, err)
						}
					}
				}
			}
		})
	}
}

func TestGenerateOfficeArtifactsRejectsUnsafeOrUnboundedInput(t *testing.T) {
	t.Parallel()
	if _, err := generateOfficeArtifact(artifactRequest{Kind: "docx", Title: "x", Paragraphs: []string{"bad\x00text"}}); err == nil {
		t.Fatal("invalid XML control character accepted")
	}
	if _, err := generateOfficeArtifact(artifactRequest{Kind: "xlsx", Title: "x", Sheets: []artifactSheet{{Name: "../secret", Rows: [][]string{{"x"}}}}}); err == nil {
		t.Fatal("unsafe worksheet name accepted")
	}
	if _, err := generateOfficeArtifact(artifactRequest{Kind: "pptx", Title: "x", Slides: make([]artifactSlide, 51)}); err == nil {
		t.Fatal("oversized slide deck accepted")
	}
}

func TestSpreadsheetColumnNames(t *testing.T) {
	t.Parallel()
	for input, want := range map[int]string{1: "A", 26: "Z", 27: "AA", 52: "AZ", 53: "BA"} {
		if got := spreadsheetColumn(input); got != want {
			t.Fatalf("column %d = %q, want %q", input, got, want)
		}
	}
}
