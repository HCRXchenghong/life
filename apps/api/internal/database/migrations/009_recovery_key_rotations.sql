ALTER TABLE content_key_envelopes
  ADD COLUMN envelope_revision BIGINT UNSIGNED NOT NULL DEFAULT 1 AFTER account_id;

CREATE TABLE content_key_envelope_rotations (
  account_id CHAR(36) NOT NULL PRIMARY KEY,
  rotation_id CHAR(36) NOT NULL UNIQUE,
  expected_revision BIGINT UNSIGNED NOT NULL,
  key_version INT NOT NULL,
  algorithm VARCHAR(32) NOT NULL,
  kdf VARCHAR(32) NOT NULL,
  salt VARBINARY(64) NOT NULL,
  nonce VARBINARY(24) NOT NULL,
  ciphertext VARBINARY(128) NOT NULL,
  creator_device_id CHAR(36) NOT NULL,
  expires_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  CONSTRAINT content_key_rotation_envelope_fk FOREIGN KEY (account_id) REFERENCES content_key_envelopes(account_id) ON DELETE CASCADE,
  INDEX content_key_rotation_expiry_idx (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
