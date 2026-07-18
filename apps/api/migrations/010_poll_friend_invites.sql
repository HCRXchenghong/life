ALTER TABLE share_polls
  ADD COLUMN selected_starts_at DATETIME(6) NULL AFTER selected_slot_id,
  ADD COLUMN selected_ends_at DATETIME(6) NULL AFTER selected_starts_at;

CREATE TABLE IF NOT EXISTS poll_friend_invites (
  id CHAR(36) PRIMARY KEY,
  poll_id CHAR(36) NOT NULL,
  display_name VARCHAR(80) NOT NULL,
  access_token_hash CHAR(64) NOT NULL,
  access_token_ciphertext VARBINARY(256) NOT NULL,
  access_token_nonce VARBINARY(32) NOT NULL,
  status ENUM('pending','submitted','revoked') NOT NULL DEFAULT 'pending',
  submitted_at DATETIME(6) NULL,
  revoked_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  UNIQUE KEY poll_friend_invite_token_uq (access_token_hash),
  KEY poll_friend_invite_poll_idx (poll_id, created_at),
  CONSTRAINT poll_friend_invite_poll_fk FOREIGN KEY (poll_id) REFERENCES share_polls(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS poll_friend_selections (
  id CHAR(36) PRIMARY KEY,
  invite_id CHAR(36) NOT NULL,
  starts_at DATETIME(6) NOT NULL,
  ends_at DATETIME(6) NOT NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  UNIQUE KEY poll_friend_selection_time_uq (invite_id, starts_at, ends_at),
  KEY poll_friend_selection_invite_idx (invite_id, starts_at),
  CONSTRAINT poll_friend_selection_invite_fk FOREIGN KEY (invite_id) REFERENCES poll_friend_invites(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
