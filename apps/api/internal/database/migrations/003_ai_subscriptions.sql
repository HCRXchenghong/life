CREATE TABLE IF NOT EXISTS ai_plan_limits (
  plan ENUM('plus','pro') PRIMARY KEY,
  weekly_units INT UNSIGNED NOT NULL DEFAULT 0,
  monthly_units INT UNSIGNED NOT NULL DEFAULT 0,
  updated_by_admin_id CHAR(36) NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  CONSTRAINT ai_plan_limit_admin_fk FOREIGN KEY (updated_by_admin_id) REFERENCES admin_accounts(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO ai_plan_limits (plan, weekly_units, monthly_units)
VALUES ('plus', 0, 0), ('pro', 0, 0)
ON DUPLICATE KEY UPDATE plan = VALUES(plan);

CREATE TABLE IF NOT EXISTS app_ai_subscriptions (
  account_id CHAR(36) PRIMARY KEY,
  plan ENUM('plus','pro','max') NOT NULL,
  card_type ENUM('week','month','quarter','year') NOT NULL,
  starts_at DATETIME(6) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  granted_by_admin_id CHAR(36) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  KEY app_ai_subscription_expiry_idx (expires_at),
  CONSTRAINT app_ai_subscription_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE,
  CONSTRAINT app_ai_subscription_admin_fk FOREIGN KEY (granted_by_admin_id) REFERENCES admin_accounts(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ai_usage_events (
  id CHAR(36) PRIMARY KEY,
  account_id CHAR(36) NOT NULL,
  mode ENUM('local_ai','ssh_agent') NOT NULL,
  kind ENUM('responses','image') NOT NULL,
  units INT UNSIGNED NOT NULL,
  status ENUM('reserved','charged','released') NOT NULL DEFAULT 'reserved',
  finalized_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  KEY ai_usage_account_created_idx (account_id, created_at),
  KEY ai_usage_account_status_created_idx (account_id, status, created_at),
  CONSTRAINT ai_usage_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS ai_gateway_tokens (
  id CHAR(36) PRIMARY KEY,
  account_id CHAR(36) NOT NULL,
  app_session_id CHAR(36) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  revoked_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY ai_gateway_token_hash_uq (token_hash),
  KEY ai_gateway_token_account_idx (account_id, created_at),
  KEY ai_gateway_token_expiry_idx (expires_at),
  CONSTRAINT ai_gateway_token_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE,
  CONSTRAINT ai_gateway_token_session_fk FOREIGN KEY (app_session_id) REFERENCES app_sessions(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

