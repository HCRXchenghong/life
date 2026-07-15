CREATE TABLE IF NOT EXISTS app_account_invitations (
  id CHAR(36) PRIMARY KEY,
  admin_id CHAR(36) NOT NULL,
  token_hash CHAR(64) NOT NULL,
  code_hash CHAR(64) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  used_at DATETIME(6) NULL,
  revoked_at DATETIME(6) NULL,
  created_account_id CHAR(36) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY app_invitation_token_uq (token_hash),
  KEY app_invitation_admin_created_idx (admin_id, created_at),
  KEY app_invitation_expiry_idx (expires_at),
  CONSTRAINT app_invitation_admin_fk FOREIGN KEY (admin_id) REFERENCES admin_accounts(id) ON DELETE CASCADE,
  CONSTRAINT app_invitation_account_fk FOREIGN KEY (created_account_id) REFERENCES app_accounts(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
