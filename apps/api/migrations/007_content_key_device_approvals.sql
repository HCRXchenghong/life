ALTER TABLE app_sessions
  ADD COLUMN e2ee_trusted BOOLEAN NOT NULL DEFAULT FALSE AFTER device_name;

CREATE TABLE IF NOT EXISTS content_key_device_approvals (
  id CHAR(36) PRIMARY KEY,
  account_id CHAR(36) NOT NULL,
  requester_session_id CHAR(36) NOT NULL,
  requester_device_name VARCHAR(80) NOT NULL,
  requester_public_key BINARY(32) NOT NULL,
  status ENUM('pending','approved','rejected','consumed','expired') NOT NULL DEFAULT 'pending',
  approver_session_id CHAR(36) NULL,
  approver_public_key BINARY(32) NULL,
  approval_nonce BINARY(12) NULL,
  approval_ciphertext BINARY(48) NULL,
  key_version INT NULL,
  expires_at DATETIME(6) NOT NULL,
  decided_at DATETIME(6) NULL,
  consumed_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  KEY content_key_device_approvals_pending_idx (account_id, status, expires_at, created_at),
  KEY content_key_device_approvals_requester_idx (requester_session_id, created_at),
  CONSTRAINT content_key_device_approvals_account_fk FOREIGN KEY (account_id) REFERENCES app_accounts(id) ON DELETE CASCADE,
  CONSTRAINT content_key_device_approvals_requester_fk FOREIGN KEY (requester_session_id) REFERENCES app_sessions(id) ON DELETE CASCADE,
  CONSTRAINT content_key_device_approvals_approver_fk FOREIGN KEY (approver_session_id) REFERENCES app_sessions(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
