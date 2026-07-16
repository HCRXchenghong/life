ALTER TABLE content_key_device_approvals
  ADD COLUMN request_token_hash BINARY(32) NULL AFTER requester_public_key;
