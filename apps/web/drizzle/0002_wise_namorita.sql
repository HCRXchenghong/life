CREATE TABLE `admin_accounts` (
	`id` text PRIMARY KEY NOT NULL,
	`singleton_key` integer DEFAULT 1 NOT NULL,
	`username` text NOT NULL,
	`username_canonical` text NOT NULL,
	`password_algorithm` text NOT NULL,
	`password_hash` text NOT NULL,
	`password_salt` text NOT NULL,
	`password_iterations` integer NOT NULL,
	`totp_secret_ciphertext` text NOT NULL,
	`totp_secret_nonce` text NOT NULL,
	`totp_last_counter` integer,
	`status` text DEFAULT 'pending' NOT NULL,
	`enrollment_token_hash` text,
	`enrollment_expires_at` text,
	`failed_login_count` integer DEFAULT 0 NOT NULL,
	`locked_until` text,
	`activated_at` text,
	`last_login_at` text,
	`password_changed_at` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `admin_accounts_singleton_idx` ON `admin_accounts` (`singleton_key`);--> statement-breakpoint
CREATE UNIQUE INDEX `admin_accounts_username_idx` ON `admin_accounts` (`username_canonical`);--> statement-breakpoint
CREATE INDEX `admin_accounts_status_idx` ON `admin_accounts` (`status`);--> statement-breakpoint
CREATE TABLE `admin_sessions` (
	`id` text PRIMARY KEY NOT NULL,
	`admin_id` text NOT NULL,
	`token_hash` text NOT NULL,
	`user_agent_hash` text,
	`expires_at` text NOT NULL,
	`last_seen_at` text NOT NULL,
	`revoked_at` text,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`admin_id`) REFERENCES `admin_accounts`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `admin_sessions_token_idx` ON `admin_sessions` (`token_hash`);--> statement-breakpoint
CREATE INDEX `admin_sessions_admin_idx` ON `admin_sessions` (`admin_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `admin_sessions_expiry_idx` ON `admin_sessions` (`expires_at`);--> statement-breakpoint
CREATE TABLE `auth_rate_limits` (
	`bucket_key` text PRIMARY KEY NOT NULL,
	`action` text NOT NULL,
	`window_started_at` text NOT NULL,
	`attempts` integer DEFAULT 0 NOT NULL,
	`blocked_until` text,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE INDEX `auth_rate_limits_updated_idx` ON `auth_rate_limits` (`updated_at`);