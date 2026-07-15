package httpapi

import (
	"context"
	"database/sql"
	"errors"
	"strings"
)

const defaultAIReasoningEffort = "medium"

var supportedAIReasoningEfforts = []string{"low", "medium", "high", "xhigh"}

type publicAIModel struct {
	ID   string `json:"id"`
	Kind string `json:"kind"`
}

type publicAIPreference struct {
	TextModel       string `json:"textModel"`
	ReasoningEffort string `json:"reasoningEffort"`
}

func classifyProviderModel(id string) string {
	lower := strings.ToLower(id)
	if strings.Contains(lower, "gpt-image") || strings.HasPrefix(lower, "dall-e") ||
		strings.Contains(lower, "imagen") || strings.Contains(lower, "stable-diffusion") {
		return "image"
	}
	for _, marker := range []string{
		"embedding", "rerank", "moderation", "transcribe", "transcription", "speech", "tts",
		"whisper", "audio", "realtime", "search-preview",
	} {
		if strings.Contains(lower, marker) {
			return "other"
		}
	}
	return "text"
}

func validAIReasoningEffort(value string) bool {
	for _, effort := range supportedAIReasoningEfforts {
		if value == effort {
			return true
		}
	}
	return false
}

func (s *Server) listProviderModels(ctx context.Context, providerID string, enabledOnly bool) ([]publicAIModel, error) {
	query := `SELECT model_id, kind FROM ai_provider_models WHERE provider_id = ?`
	if enabledOnly {
		query += " AND enabled = TRUE"
	}
	query += " ORDER BY FIELD(kind, 'text', 'image', 'other'), model_id"
	rows, err := s.db.QueryContext(ctx, query, providerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	models := make([]publicAIModel, 0)
	for rows.Next() {
		var model publicAIModel
		if err := rows.Scan(&model.ID, &model.Kind); err != nil {
			return nil, err
		}
		models = append(models, model)
	}
	return models, rows.Err()
}

func (s *Server) resolveAISelection(ctx context.Context, accountID string, provider providerSecret, requestedModel, requestedEffort string) (publicAIPreference, error) {
	preference := publicAIPreference{TextModel: provider.TextModel, ReasoningEffort: defaultAIReasoningEffort}
	var saved publicAIPreference
	err := s.db.QueryRowContext(ctx, `SELECT text_model, reasoning_effort FROM app_ai_preferences
      WHERE account_id = ? AND provider_id = ?`, accountID, provider.ID).
		Scan(&saved.TextModel, &saved.ReasoningEffort)
	if err == nil {
		preference = saved
	} else if !errors.Is(err, sql.ErrNoRows) {
		return publicAIPreference{}, err
	}
	if requestedModel = strings.TrimSpace(requestedModel); requestedModel != "" {
		preference.TextModel = requestedModel
	}
	if requestedEffort = strings.TrimSpace(requestedEffort); requestedEffort != "" {
		preference.ReasoningEffort = requestedEffort
	}
	if !validAIReasoningEffort(preference.ReasoningEffort) {
		return publicAIPreference{}, errors.New("unsupported reasoning effort")
	}
	var exists int
	if err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM ai_provider_models
      WHERE provider_id = ? AND model_id = ? AND kind = 'text' AND enabled = TRUE`,
		provider.ID, preference.TextModel).Scan(&exists); err != nil {
		return publicAIPreference{}, err
	}
	if exists != 1 {
		if requestedModel != "" {
			return publicAIPreference{}, errors.New("model is unavailable")
		}
		preference.TextModel = provider.TextModel
		if err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM ai_provider_models
          WHERE provider_id = ? AND model_id = ? AND kind = 'text' AND enabled = TRUE`,
			provider.ID, preference.TextModel).Scan(&exists); err != nil || exists != 1 {
			if err != nil {
				return publicAIPreference{}, err
			}
			return publicAIPreference{}, errors.New("model catalog is unavailable")
		}
	}
	return preference, nil
}

func (s *Server) modelIsEnabled(ctx context.Context, providerID, modelID, kind string) (bool, error) {
	var exists int
	err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM ai_provider_models
      WHERE provider_id = ? AND model_id = ? AND kind = ? AND enabled = TRUE`, providerID, modelID, kind).Scan(&exists)
	return exists == 1, err
}
