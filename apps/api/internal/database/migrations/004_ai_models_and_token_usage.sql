ALTER TABLE ai_plan_limits
  MODIFY monthly_units BIGINT UNSIGNED NOT NULL DEFAULT 0;

ALTER TABLE ai_usage_events
  MODIFY units BIGINT UNSIGNED NOT NULL DEFAULT 0,
  ADD COLUMN reserved_units BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER units,
  ADD COLUMN model VARCHAR(120) NOT NULL DEFAULT '' AFTER kind,
  ADD COLUMN input_tokens BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER reserved_units,
  ADD COLUMN output_tokens BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER input_tokens,
  ADD COLUMN cached_input_tokens BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER output_tokens,
  ADD COLUMN reasoning_tokens BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER cached_input_tokens;

CREATE TABLE IF NOT EXISTS ai_provider_models (
  provider_id CHAR(36) NOT NULL,
  model_id VARCHAR(120) NOT NULL,
  kind ENUM('text','image','other') NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  discovered_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (provider_id, model_id),
  KEY ai_provider_models_enabled_idx (provider_id, enabled, kind, model_id),
  CONSTRAINT ai_provider_models_provider_fk FOREIGN KEY (provider_id) REFERENCES ai_provider_configs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO ai_provider_models (provider_id, model_id, kind, enabled)
SELECT id, text_model, 'text', TRUE FROM ai_provider_configs
ON DUPLICATE KEY UPDATE kind = VALUES(kind), enabled = TRUE;

INSERT INTO ai_provider_models (provider_id, model_id, kind, enabled)
SELECT id, image_model, 'image', TRUE FROM ai_provider_configs WHERE image_model IS NOT NULL AND image_model <> ''
ON DUPLICATE KEY UPDATE kind = VALUES(kind), enabled = TRUE;

CREATE TABLE IF NOT EXISTS app_ai_preferences (
  account_id CHAR(36) PRIMARY KEY,
  provider_id CHAR(36) NOT NULL,
  text_model VARCHAR(120) NOT NULL,
  reasoning_effort ENUM('low','medium','high','xhigh') NOT NULL DEFAULT 'medium',
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  KEY app_ai_preferences_provider_idx (provider_id, text_model),
  CONSTRAINT app_ai_preferences_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE,
  CONSTRAINT app_ai_preferences_provider_fk FOREIGN KEY (provider_id) REFERENCES ai_provider_configs(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
