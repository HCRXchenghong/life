CREATE TABLE `mobile_api_tokens` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_email` text NOT NULL,
	`name` text NOT NULL,
	`token_hash` text NOT NULL,
	`token_hint` text NOT NULL,
	`expires_at` text,
	`last_used_at` text,
	`revoked_at` text,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `mobile_api_tokens_hash_idx` ON `mobile_api_tokens` (`token_hash`);--> statement-breakpoint
CREATE INDEX `mobile_api_tokens_owner_idx` ON `mobile_api_tokens` (`owner_email`,`created_at`);