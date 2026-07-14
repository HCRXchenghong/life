CREATE TABLE `app_accounts` (
	`id` text PRIMARY KEY NOT NULL,
	`username` text NOT NULL,
	`username_canonical` text NOT NULL,
	`password_algorithm` text NOT NULL,
	`password_hash` text NOT NULL,
	`password_salt` text NOT NULL,
	`password_iterations` integer NOT NULL,
	`password_change_required` integer DEFAULT true NOT NULL,
	`status` text DEFAULT 'active' NOT NULL,
	`failed_login_count` integer DEFAULT 0 NOT NULL,
	`locked_until` text,
	`last_login_at` text,
	`password_changed_at` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `app_accounts_username_idx` ON `app_accounts` (`username_canonical`);--> statement-breakpoint
CREATE INDEX `app_accounts_status_idx` ON `app_accounts` (`status`);--> statement-breakpoint
CREATE INDEX `app_accounts_created_idx` ON `app_accounts` (`created_at`);--> statement-breakpoint
CREATE TABLE `app_sessions` (
	`id` text PRIMARY KEY NOT NULL,
	`account_id` text NOT NULL,
	`access_token_hash` text NOT NULL,
	`refresh_token_hash` text NOT NULL,
	`device_name` text NOT NULL,
	`access_expires_at` text NOT NULL,
	`refresh_expires_at` text NOT NULL,
	`last_seen_at` text NOT NULL,
	`revoked_at` text,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`account_id`) REFERENCES `app_accounts`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `app_sessions_access_token_idx` ON `app_sessions` (`access_token_hash`);--> statement-breakpoint
CREATE UNIQUE INDEX `app_sessions_refresh_token_idx` ON `app_sessions` (`refresh_token_hash`);--> statement-breakpoint
CREATE INDEX `app_sessions_account_idx` ON `app_sessions` (`account_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `app_sessions_refresh_expiry_idx` ON `app_sessions` (`refresh_expires_at`);