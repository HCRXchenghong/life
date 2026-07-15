CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(64) PRIMARY KEY,
  applied_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS admin_accounts (
  id CHAR(36) PRIMARY KEY,
  singleton_key TINYINT NOT NULL DEFAULT 1,
  username VARCHAR(32) NOT NULL,
  username_canonical VARCHAR(32) NOT NULL,
  password_algorithm VARCHAR(64) NOT NULL,
  password_hash VARCHAR(128) NOT NULL,
  password_salt VARCHAR(64) NOT NULL,
  password_iterations INT NOT NULL,
  totp_secret_ciphertext VARBINARY(256) NOT NULL,
  totp_secret_nonce VARBINARY(32) NOT NULL,
  totp_last_counter BIGINT NULL,
  status ENUM('pending','active','disabled') NOT NULL DEFAULT 'pending',
  enrollment_token_hash CHAR(64) NULL,
  enrollment_expires_at DATETIME(6) NULL,
  failed_login_count INT NOT NULL DEFAULT 0,
  locked_until DATETIME(6) NULL,
  activated_at DATETIME(6) NULL,
  last_login_at DATETIME(6) NULL,
  password_changed_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  UNIQUE KEY admin_singleton_uq (singleton_key),
  UNIQUE KEY admin_username_uq (username_canonical),
  CONSTRAINT admin_singleton_ck CHECK (singleton_key = 1)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS admin_sessions (
  id CHAR(36) PRIMARY KEY,
  admin_id CHAR(36) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  user_agent_hash CHAR(64) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  last_seen_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY admin_session_token_uq (token_hash),
  KEY admin_session_admin_idx (admin_id, created_at),
  KEY admin_session_expiry_idx (expires_at),
  CONSTRAINT admin_session_admin_fk FOREIGN KEY (admin_id) REFERENCES admin_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS admin_totp_rebindings (
  id CHAR(36) PRIMARY KEY,
  admin_id CHAR(36) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  secret_ciphertext VARBINARY(256) NOT NULL,
  secret_nonce VARBINARY(32) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY admin_totp_rebind_admin_uq (admin_id),
  UNIQUE KEY admin_totp_rebind_token_uq (token_hash),
  CONSTRAINT admin_totp_rebind_admin_fk FOREIGN KEY (admin_id) REFERENCES admin_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS auth_rate_limits (
  bucket_key CHAR(64) PRIMARY KEY,
  action VARCHAR(64) NOT NULL,
  window_started_at DATETIME(6) NOT NULL,
  attempts INT NOT NULL DEFAULT 0,
  blocked_until DATETIME(6) NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  KEY rate_limit_updated_idx (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS app_accounts (
  id CHAR(36) PRIMARY KEY,
  username VARCHAR(32) NOT NULL,
  username_canonical VARCHAR(32) NOT NULL,
  password_algorithm VARCHAR(64) NOT NULL,
  password_hash VARCHAR(128) NOT NULL,
  password_salt VARCHAR(64) NOT NULL,
  password_iterations INT NOT NULL,
  password_change_required BOOLEAN NOT NULL DEFAULT TRUE,
  status ENUM('active','disabled') NOT NULL DEFAULT 'active',
  failed_login_count INT NOT NULL DEFAULT 0,
  locked_until DATETIME(6) NULL,
  last_login_at DATETIME(6) NULL,
  password_changed_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  UNIQUE KEY app_account_username_uq (username_canonical),
  KEY app_account_status_idx (status, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS app_sessions (
  id CHAR(36) PRIMARY KEY,
  account_id CHAR(36) NOT NULL,
  access_token_hash CHAR(64) NOT NULL,
  refresh_token_hash CHAR(64) NOT NULL,
  device_name VARCHAR(80) NOT NULL,
  access_expires_at DATETIME(6) NOT NULL,
  refresh_expires_at DATETIME(6) NOT NULL,
  last_seen_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY app_session_access_uq (access_token_hash),
  UNIQUE KEY app_session_refresh_uq (refresh_token_hash),
  KEY app_session_account_idx (account_id, created_at),
  KEY app_session_refresh_expiry_idx (refresh_expires_at),
  CONSTRAINT app_session_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ai_provider_configs (
  id CHAR(36) PRIMARY KEY,
  admin_id CHAR(36) NOT NULL,
  name VARCHAR(80) NOT NULL,
  kind ENUM('openai_responses','openai_compatible') NOT NULL,
  base_url VARCHAR(400) NOT NULL,
  text_model VARCHAR(120) NOT NULL,
  image_model VARCHAR(120) NULL,
  api_key_ciphertext VARBINARY(8192) NOT NULL,
  api_key_nonce VARBINARY(32) NOT NULL,
  api_key_hint VARCHAR(32) NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  UNIQUE KEY ai_provider_admin_name_uq (admin_id, name),
  KEY ai_provider_admin_idx (admin_id, updated_at),
  CONSTRAINT ai_provider_admin_fk FOREIGN KEY (admin_id) REFERENCES admin_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ai_runs (
  id CHAR(36) PRIMARY KEY,
  actor_id CHAR(36) NOT NULL,
  provider_config_id CHAR(36) NOT NULL,
  kind ENUM('assistant','image','provider_test') NOT NULL,
  status ENUM('queued','running','succeeded','failed','cancelled') NOT NULL,
  model VARCHAR(120) NOT NULL,
  request_digest CHAR(64) NOT NULL,
  response_id VARCHAR(200) NULL,
  error_code VARCHAR(80) NULL,
  error_message VARCHAR(1000) NULL,
  started_at DATETIME(6) NULL,
  completed_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  KEY ai_run_actor_idx (actor_id, created_at),
  CONSTRAINT ai_run_provider_fk FOREIGN KEY (provider_config_id) REFERENCES ai_provider_configs(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS audit_events (
  id CHAR(36) PRIMARY KEY,
  actor VARCHAR(100) NOT NULL,
  action VARCHAR(100) NOT NULL,
  target_type VARCHAR(80) NOT NULL,
  target_id CHAR(36) NULL,
  outcome ENUM('allowed','denied','failed') NOT NULL,
  risk ENUM('read_only','low','medium','high','critical') NOT NULL DEFAULT 'low',
  request_id VARCHAR(128) NULL,
  metadata_json JSON NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  KEY audit_actor_created_idx (actor, created_at),
  KEY audit_created_idx (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS share_polls (
  id CHAR(36) PRIMARY KEY,
  account_id CHAR(36) NOT NULL,
  title VARCHAR(160) NOT NULL,
  description VARCHAR(2000) NOT NULL DEFAULT '',
  timezone VARCHAR(80) NOT NULL,
  public_token_hash CHAR(64) NOT NULL,
  manage_token_hash CHAR(64) NOT NULL,
  status ENUM('open','closed','cancelled','expired') NOT NULL DEFAULT 'open',
  closes_at DATETIME(6) NULL,
  selected_slot_id CHAR(36) NULL,
  version BIGINT NOT NULL DEFAULT 1,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  UNIQUE KEY poll_public_token_uq (public_token_hash),
  UNIQUE KEY poll_manage_token_uq (manage_token_hash),
  KEY poll_account_idx (account_id, created_at),
  CONSTRAINT poll_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS share_slots (
  id CHAR(36) PRIMARY KEY,
  poll_id CHAR(36) NOT NULL,
  label VARCHAR(120) NOT NULL DEFAULT '',
  starts_at DATETIME(6) NOT NULL,
  ends_at DATETIME(6) NOT NULL,
  sort_order INT NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY slot_poll_time_uq (poll_id, starts_at, ends_at),
  KEY slot_poll_idx (poll_id, sort_order),
  CONSTRAINT slot_poll_fk FOREIGN KEY (poll_id) REFERENCES share_polls(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS poll_participants (
  id CHAR(36) PRIMARY KEY,
  poll_id CHAR(36) NOT NULL,
  display_name VARCHAR(80) NOT NULL,
  edit_token_hash CHAR(64) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  UNIQUE KEY participant_edit_token_uq (edit_token_hash),
  KEY participant_poll_idx (poll_id),
  CONSTRAINT participant_poll_fk FOREIGN KEY (poll_id) REFERENCES share_polls(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS poll_votes (
  participant_id CHAR(36) NOT NULL,
  slot_id CHAR(36) NOT NULL,
  response ENUM('yes','maybe','no') NOT NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (participant_id, slot_id),
  CONSTRAINT vote_participant_fk FOREIGN KEY (participant_id) REFERENCES poll_participants(id) ON DELETE CASCADE,
  CONSTRAINT vote_slot_fk FOREIGN KEY (slot_id) REFERENCES share_slots(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS generated_assets (
  id CHAR(36) PRIMARY KEY,
  admin_id CHAR(36) NOT NULL,
  provider_config_id CHAR(36) NOT NULL,
  ai_run_id CHAR(36) NULL,
  object_key VARCHAR(500) NOT NULL,
  prompt_digest CHAR(64) NOT NULL,
  content_type VARCHAR(100) NOT NULL,
  byte_size BIGINT NOT NULL,
  width INT NULL,
  height INT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY generated_asset_object_uq (object_key),
  KEY generated_asset_admin_idx (admin_id, created_at),
  CONSTRAINT asset_admin_fk FOREIGN KEY (admin_id) REFERENCES admin_accounts(id) ON DELETE CASCADE,
  CONSTRAINT asset_provider_fk FOREIGN KEY (provider_config_id) REFERENCES ai_provider_configs(id) ON DELETE RESTRICT,
  CONSTRAINT asset_run_fk FOREIGN KEY (ai_run_id) REFERENCES ai_runs(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sync_objects (
  account_id CHAR(36) NOT NULL,
  collection_name VARCHAR(64) NOT NULL,
  object_id CHAR(36) NOT NULL,
  revision BIGINT NOT NULL,
  ciphertext MEDIUMBLOB NOT NULL,
  nonce VARBINARY(64) NOT NULL,
  key_version INT NOT NULL,
  last_device_id CHAR(36) NOT NULL,
  deleted BOOLEAN NOT NULL DEFAULT FALSE,
  client_updated_at DATETIME(6) NOT NULL,
  server_updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (account_id, collection_name, object_id),
  KEY sync_objects_account_updated_idx (account_id, server_updated_at),
  CONSTRAINT sync_object_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS sync_events (
  sequence_id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  account_id CHAR(36) NOT NULL,
  collection_name VARCHAR(64) NOT NULL,
  object_id CHAR(36) NOT NULL,
  operation_id CHAR(36) NOT NULL,
  device_id CHAR(36) NOT NULL,
  revision BIGINT NOT NULL,
  deleted BOOLEAN NOT NULL,
  ciphertext MEDIUMBLOB NOT NULL,
  nonce VARBINARY(64) NOT NULL,
  key_version INT NOT NULL,
  client_updated_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  KEY sync_events_account_sequence_idx (account_id, sequence_id),
  UNIQUE KEY sync_events_account_operation_uq (account_id, operation_id),
  CONSTRAINT sync_event_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
