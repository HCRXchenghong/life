package httpapi

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/HCRXchenghong/life/apps/api/internal/security"
)

const (
	builtInPosterTemplateID   = "00000000-0000-4000-8000-000000000011"
	builtInPosterTemplateCode = "minimal-blue"
)

const builtInMinimalPosterSchema = `{
  "schemaVersion": 1,
  "canvas": {"width": 1080, "height": 1440, "backgroundColor": "#FFFFFF"},
  "layers": [
    {"type":"shape","shape":"ellipse","x":770,"y":410,"width":640,"height":1120,"fillColor":"#00000000","strokeColor":"#3370FF","strokeWidth":72},
    {"type":"text","binding":"brandName","x":96,"y":76,"width":420,"height":70,"fontSize":42,"minFontSize":36,"maxLines":1,"fontWeight":700,"color":"#3370FF","align":"start"},
    {"type":"text","binding":"salutation","x":96,"y":230,"width":720,"height":300,"fontSize":82,"minFontSize":48,"maxLines":3,"fontWeight":700,"color":"#1F2329","align":"start"},
    {"type":"shape","shape":"rect","x":96,"y":548,"width":620,"height":2,"fillColor":"#D9DCE3","strokeColor":"#00000000","strokeWidth":0},
    {"type":"text","binding":"activityTitle","x":96,"y":590,"width":620,"height":78,"fontSize":45,"minFontSize":34,"maxLines":1,"fontWeight":700,"color":"#1F2329","align":"start"},
    {"type":"text","binding":"activityDescription","x":96,"y":675,"width":620,"height":90,"fontSize":29,"minFontSize":23,"maxLines":2,"fontWeight":400,"color":"#646A73","align":"start"},
    {"type":"text","binding":"dateRange","x":96,"y":790,"width":620,"height":48,"fontSize":31,"minFontSize":25,"maxLines":1,"fontWeight":600,"color":"#1F2329","align":"start"},
    {"type":"text","binding":"deadline","x":96,"y":840,"width":620,"height":42,"fontSize":25,"minFontSize":21,"maxLines":1,"fontWeight":400,"color":"#646A73","align":"start"},
    {"type":"qr","binding":"inviteUrl","x":96,"y":905,"width":324,"height":324,"quietZone":32},
    {"type":"text","binding":"qrLabel","x":96,"y":1248,"width":420,"height":50,"fontSize":30,"minFontSize":25,"maxLines":1,"fontWeight":700,"color":"#3370FF","align":"start"},
    {"type":"text","binding":"privateHint","x":96,"y":1310,"width":520,"height":42,"fontSize":24,"minFontSize":20,"maxLines":1,"fontWeight":400,"color":"#646A73","align":"start"}
  ]
}`

var posterColorPattern = regexp.MustCompile(`^#[0-9A-Fa-f]{8}$|^#[0-9A-Fa-f]{6}$`)

type posterTemplateSchema struct {
	SchemaVersion int                   `json:"schemaVersion"`
	Canvas        posterTemplateCanvas  `json:"canvas"`
	Layers        []posterTemplateLayer `json:"layers"`
}

type posterTemplateCanvas struct {
	Width           float64 `json:"width"`
	Height          float64 `json:"height"`
	BackgroundColor string  `json:"backgroundColor"`
}

type posterTemplateLayer struct {
	Type        string  `json:"type"`
	Binding     string  `json:"binding,omitempty"`
	Shape       string  `json:"shape,omitempty"`
	X           float64 `json:"x"`
	Y           float64 `json:"y"`
	Width       float64 `json:"width"`
	Height      float64 `json:"height"`
	FontSize    float64 `json:"fontSize,omitempty"`
	MinFontSize float64 `json:"minFontSize,omitempty"`
	MaxLines    int     `json:"maxLines,omitempty"`
	FontWeight  int     `json:"fontWeight,omitempty"`
	Color       string  `json:"color,omitempty"`
	Align       string  `json:"align,omitempty"`
	FillColor   string  `json:"fillColor,omitempty"`
	StrokeColor string  `json:"strokeColor,omitempty"`
	StrokeWidth float64 `json:"strokeWidth,omitempty"`
	QuietZone   float64 `json:"quietZone,omitempty"`
}

type posterTemplateRecord struct {
	ID        string
	Code      string
	Name      string
	Status    string
	Version   int
	BuiltIn   bool
	Schema    json.RawMessage
	Hash      string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type adminPosterTemplateCreateInput struct {
	Name   string          `json:"name"`
	Status string          `json:"status"`
	Schema json.RawMessage `json:"schema"`
}

type adminPosterTemplateUpdateInput struct {
	Name   *string          `json:"name"`
	Status *string          `json:"status"`
	Schema *json.RawMessage `json:"schema"`
}

func (s *Server) ensureBuiltInPosterTemplate() {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	canonical, _, err := validatePosterTemplateSchema(json.RawMessage(builtInMinimalPosterSchema))
	if err != nil {
		s.logger.Error("built-in poster template is invalid")
		return
	}
	tx, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		s.logger.Warn("unable to initialize built-in poster template")
		return
	}
	defer func() { _ = tx.Rollback() }()
	if _, err = tx.ExecContext(ctx, `INSERT INTO poster_templates
      (id, code, name, status, current_version, built_in) VALUES (?, ?, ?, 'published', 1, TRUE)
      ON DUPLICATE KEY UPDATE built_in = TRUE`, builtInPosterTemplateID, builtInPosterTemplateCode, "极简蓝白"); err != nil {
		s.logger.Warn("unable to initialize built-in poster template")
		return
	}
	if _, err = tx.ExecContext(ctx, `INSERT IGNORE INTO poster_template_versions
      (template_id, version, schema_json, schema_hash) VALUES (?, 1, ?, ?)`, builtInPosterTemplateID, canonical, security.SHA256(string(canonical))); err != nil {
		s.logger.Warn("unable to initialize built-in poster template")
		return
	}
	if err = tx.Commit(); err != nil {
		s.logger.Warn("unable to initialize built-in poster template")
	}
}

func (s *Server) handlePosterTemplates(w http.ResponseWriter, r *http.Request) {
	if _, ok := s.requireApp(w, r); !ok {
		return
	}
	templates, err := s.listPosterTemplates(r.Context(), true)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "poster_templates_unavailable", "海报模板暂时不可用")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"templates": templates})
}

func (s *Server) handleAdminPosterTemplates(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if r.Method == http.MethodGet {
		templates, err := s.listPosterTemplates(r.Context(), false)
		if err != nil {
			writeError(w, http.StatusServiceUnavailable, "poster_templates_unavailable", "海报模板暂时不可用")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"templates": templates})
		return
	}
	if !s.requireSameOrigin(w, r) {
		return
	}
	var input adminPosterTemplateCreateInput
	if decodeJSON(r, &input) != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "模板信息无效")
		return
	}
	input.Name = strings.TrimSpace(input.Name)
	if len([]rune(input.Name)) < 1 || len([]rune(input.Name)) > 80 || !validPosterTemplateStatus(input.Status) {
		writeError(w, http.StatusBadRequest, "invalid_request", "模板名称或状态无效")
		return
	}
	canonical, _, err := validatePosterTemplateSchema(input.Schema)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_template", err.Error())
		return
	}
	id, err := security.RandomID()
	if err != nil {
		writeError(w, http.StatusInternalServerError, "template_create_failed", "暂时无法创建模板")
		return
	}
	code := "custom-" + strings.ReplaceAll(id, "-", "")[:16]
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "template_create_failed", "暂时无法创建模板")
		return
	}
	defer func() { _ = tx.Rollback() }()
	if _, err = tx.ExecContext(r.Context(), `INSERT INTO poster_templates
      (id, code, name, status, current_version, built_in) VALUES (?, ?, ?, ?, 1, FALSE)`, id, code, input.Name, input.Status); err == nil {
		_, err = tx.ExecContext(r.Context(), `INSERT INTO poster_template_versions
        (template_id, version, schema_json, schema_hash) VALUES (?, 1, ?, ?)`, id, canonical, security.SHA256(string(canonical)))
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "template_create_failed", "暂时无法创建模板")
		return
	}
	s.audit(r.Context(), identity.Actor, "poster_template.create", "poster_template", id, "allowed", "medium")
	record, err := s.posterTemplateByID(r.Context(), id)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "template_create_failed", "模板已创建，请刷新页面")
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"template": posterTemplateJSON(record)})
}

func (s *Server) handleAdminPosterTemplate(w http.ResponseWriter, r *http.Request) {
	identity, ok := s.requireAdmin(w, r)
	if !ok {
		return
	}
	if !s.requireSameOrigin(w, r) {
		return
	}
	var input adminPosterTemplateUpdateInput
	if decodeJSON(r, &input) != nil || (input.Name == nil && input.Status == nil && input.Schema == nil) {
		writeError(w, http.StatusBadRequest, "invalid_request", "模板信息无效")
		return
	}
	current, err := s.posterTemplateByID(r.Context(), r.PathValue("id"))
	if errors.Is(err, sql.ErrNoRows) {
		writeError(w, http.StatusNotFound, "not_found", "海报模板不存在")
		return
	}
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "template_update_failed", "暂时无法更新模板")
		return
	}
	name, status := current.Name, current.Status
	if input.Name != nil {
		name = strings.TrimSpace(*input.Name)
	}
	if input.Status != nil {
		status = strings.TrimSpace(*input.Status)
	}
	if len([]rune(name)) < 1 || len([]rune(name)) > 80 || !validPosterTemplateStatus(status) {
		writeError(w, http.StatusBadRequest, "invalid_request", "模板名称或状态无效")
		return
	}
	canonical := current.Schema
	version := current.Version
	if input.Schema != nil {
		canonical, _, err = validatePosterTemplateSchema(*input.Schema)
		if err != nil {
			writeError(w, http.StatusBadRequest, "invalid_template", err.Error())
			return
		}
		version++
	}
	tx, err := s.db.BeginTx(r.Context(), nil)
	if err != nil {
		writeError(w, http.StatusServiceUnavailable, "template_update_failed", "暂时无法更新模板")
		return
	}
	defer func() { _ = tx.Rollback() }()
	if input.Schema != nil {
		_, err = tx.ExecContext(r.Context(), `INSERT INTO poster_template_versions
        (template_id, version, schema_json, schema_hash) VALUES (?, ?, ?, ?)`, current.ID, version, canonical, security.SHA256(string(canonical)))
	}
	if err == nil {
		_, err = tx.ExecContext(r.Context(), `UPDATE poster_templates SET name = ?, status = ?, current_version = ? WHERE id = ?`, name, status, version, current.ID)
	}
	if err != nil || tx.Commit() != nil {
		writeError(w, http.StatusInternalServerError, "template_update_failed", "暂时无法更新模板")
		return
	}
	s.audit(r.Context(), identity.Actor, "poster_template.update", "poster_template", current.ID, "allowed", "medium")
	record, err := s.posterTemplateByID(r.Context(), current.ID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "template_update_failed", "模板已更新，请刷新页面")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"template": posterTemplateJSON(record)})
}

func (s *Server) listPosterTemplates(ctx context.Context, publishedOnly bool) ([]map[string]any, error) {
	query := `SELECT t.id, t.code, t.name, t.status, t.current_version, t.built_in,
      v.schema_json, v.schema_hash, t.created_at, t.updated_at
      FROM poster_templates t JOIN poster_template_versions v
        ON v.template_id = t.id AND v.version = t.current_version`
	if publishedOnly {
		query += " WHERE t.status = 'published'"
	}
	query += " ORDER BY t.built_in DESC, t.created_at, t.id"
	rows, err := s.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	values := make([]map[string]any, 0)
	for rows.Next() {
		var record posterTemplateRecord
		if err = rows.Scan(&record.ID, &record.Code, &record.Name, &record.Status, &record.Version, &record.BuiltIn, &record.Schema, &record.Hash, &record.CreatedAt, &record.UpdatedAt); err != nil {
			return nil, err
		}
		values = append(values, posterTemplateJSON(record))
	}
	return values, rows.Err()
}

func (s *Server) posterTemplateByID(ctx context.Context, id string) (posterTemplateRecord, error) {
	var record posterTemplateRecord
	err := s.db.QueryRowContext(ctx, `SELECT t.id, t.code, t.name, t.status, t.current_version, t.built_in,
      v.schema_json, v.schema_hash, t.created_at, t.updated_at
      FROM poster_templates t JOIN poster_template_versions v
        ON v.template_id = t.id AND v.version = t.current_version WHERE t.id = ? LIMIT 1`, id).
		Scan(&record.ID, &record.Code, &record.Name, &record.Status, &record.Version, &record.BuiltIn, &record.Schema, &record.Hash, &record.CreatedAt, &record.UpdatedAt)
	return record, err
}

func posterTemplateJSON(record posterTemplateRecord) map[string]any {
	var schema any
	if json.Unmarshal(record.Schema, &schema) != nil {
		schema = map[string]any{}
	}
	return map[string]any{
		"id": record.ID, "code": record.Code, "name": record.Name, "status": record.Status,
		"version": record.Version, "builtIn": record.BuiltIn, "schema": schema,
		"schemaHash": record.Hash, "createdAt": record.CreatedAt, "updatedAt": record.UpdatedAt,
	}
}

func validatePosterTemplateSchema(raw json.RawMessage) (json.RawMessage, posterTemplateSchema, error) {
	var schema posterTemplateSchema
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&schema); err != nil {
		return nil, schema, errors.New("模板结构无效")
	}
	if decoder.Decode(&struct{}{}) != io.EOF {
		return nil, schema, errors.New("模板结构无效")
	}
	if schema.SchemaVersion != 1 || schema.Canvas.Width < 320 || schema.Canvas.Width > 4096 || schema.Canvas.Height < 480 || schema.Canvas.Height > 4096 || !posterColorPattern.MatchString(schema.Canvas.BackgroundColor) {
		return nil, schema, errors.New("模板画布无效")
	}
	if len(schema.Layers) < 1 || len(schema.Layers) > 40 {
		return nil, schema, errors.New("模板图层数量无效")
	}
	allowedBindings := map[string]bool{
		"brandName": true, "friendName": true, "salutation": true, "activityTitle": true,
		"activityDescription": true, "dateRange": true, "deadline": true,
		"organizerName": true, "inviteUrl": true, "qrLabel": true, "privateHint": true,
	}
	qrCount := 0
	for index, layer := range schema.Layers {
		fullyInside := layer.X >= 0 && layer.Y >= 0 && layer.Width > 0 && layer.Height > 0 &&
			layer.X+layer.Width <= schema.Canvas.Width+0.01 && layer.Y+layer.Height <= schema.Canvas.Height+0.01
		partiallyVisibleShape := layer.Type == "shape" && layer.Width > 0 && layer.Height > 0 &&
			layer.X < schema.Canvas.Width && layer.Y < schema.Canvas.Height && layer.X+layer.Width > 0 && layer.Y+layer.Height > 0
		if !fullyInside && !partiallyVisibleShape {
			return nil, schema, fmt.Errorf("第 %d 个图层超出画布", index+1)
		}
		switch layer.Type {
		case "text":
			if !allowedBindings[layer.Binding] || layer.Binding == "inviteUrl" || layer.FontSize < 8 || layer.FontSize > 240 || layer.MinFontSize < 8 || layer.MinFontSize > layer.FontSize || layer.MaxLines < 1 || layer.MaxLines > 6 || !posterColorPattern.MatchString(layer.Color) || (layer.FontWeight != 400 && layer.FontWeight != 500 && layer.FontWeight != 600 && layer.FontWeight != 700) || (layer.Align != "start" && layer.Align != "center" && layer.Align != "end") {
				return nil, schema, fmt.Errorf("第 %d 个文字图层无效", index+1)
			}
		case "qr":
			qrCount++
			if layer.Binding != "inviteUrl" || layer.Width != layer.Height || layer.QuietZone < 0 || layer.QuietZone > 64 || layer.QuietZone*2 >= layer.Width {
				return nil, schema, fmt.Errorf("第 %d 个二维码图层无效", index+1)
			}
		case "shape":
			if layer.Shape != "rect" && layer.Shape != "ellipse" {
				return nil, schema, fmt.Errorf("第 %d 个图形图层无效", index+1)
			}
			if !posterColorPattern.MatchString(layer.FillColor) || !posterColorPattern.MatchString(layer.StrokeColor) || layer.StrokeWidth < 0 || layer.StrokeWidth > 160 {
				return nil, schema, fmt.Errorf("第 %d 个图形样式无效", index+1)
			}
		default:
			return nil, schema, fmt.Errorf("第 %d 个图层类型不受支持", index+1)
		}
	}
	if qrCount != 1 {
		return nil, schema, errors.New("模板必须且只能包含一个二维码")
	}
	canonical, err := json.Marshal(schema)
	if err != nil {
		return nil, schema, errors.New("模板结构无效")
	}
	return canonical, schema, nil
}

func validPosterTemplateStatus(value string) bool {
	return value == "draft" || value == "published" || value == "disabled"
}
