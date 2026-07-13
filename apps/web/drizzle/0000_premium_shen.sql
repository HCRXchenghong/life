CREATE TABLE `ai_provider_configs` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_email` text NOT NULL,
	`name` text NOT NULL,
	`kind` text NOT NULL,
	`base_url` text NOT NULL,
	`text_model` text NOT NULL,
	`image_model` text,
	`api_key_ciphertext` text NOT NULL,
	`api_key_nonce` text NOT NULL,
	`api_key_hint` text NOT NULL,
	`enabled` integer DEFAULT true NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE INDEX `ai_provider_owner_idx` ON `ai_provider_configs` (`owner_email`);--> statement-breakpoint
CREATE UNIQUE INDEX `ai_provider_owner_name_idx` ON `ai_provider_configs` (`owner_email`,`name`);--> statement-breakpoint
CREATE TABLE `ai_runs` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_email` text NOT NULL,
	`provider_config_id` text NOT NULL,
	`kind` text NOT NULL,
	`status` text NOT NULL,
	`model` text NOT NULL,
	`request_digest` text NOT NULL,
	`response_id` text,
	`error_code` text,
	`error_message` text,
	`started_at` text,
	`completed_at` text,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`provider_config_id`) REFERENCES `ai_provider_configs`(`id`) ON UPDATE no action ON DELETE restrict
);
--> statement-breakpoint
CREATE INDEX `ai_runs_owner_created_idx` ON `ai_runs` (`owner_email`,`created_at`);--> statement-breakpoint
CREATE TABLE `audit_events` (
	`id` text PRIMARY KEY NOT NULL,
	`actor` text NOT NULL,
	`action` text NOT NULL,
	`target_type` text NOT NULL,
	`target_id` text,
	`outcome` text NOT NULL,
	`risk` text DEFAULT 'low' NOT NULL,
	`request_id` text,
	`metadata_json` text DEFAULT '{}' NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE INDEX `audit_actor_created_idx` ON `audit_events` (`actor`,`created_at`);--> statement-breakpoint
CREATE TABLE `generated_assets` (
	`id` text PRIMARY KEY NOT NULL,
	`owner_email` text NOT NULL,
	`provider_config_id` text NOT NULL,
	`ai_run_id` text,
	`r2_key` text NOT NULL,
	`prompt_digest` text NOT NULL,
	`content_type` text NOT NULL,
	`byte_size` integer NOT NULL,
	`width` integer,
	`height` integer,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`provider_config_id`) REFERENCES `ai_provider_configs`(`id`) ON UPDATE no action ON DELETE restrict,
	FOREIGN KEY (`ai_run_id`) REFERENCES `ai_runs`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE UNIQUE INDEX `generated_assets_r2_key_idx` ON `generated_assets` (`r2_key`);--> statement-breakpoint
CREATE INDEX `generated_assets_owner_idx` ON `generated_assets` (`owner_email`,`created_at`);--> statement-breakpoint
CREATE TABLE `poll_participants` (
	`id` text PRIMARY KEY NOT NULL,
	`poll_id` text NOT NULL,
	`display_name` text NOT NULL,
	`edit_token_hash` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`poll_id`) REFERENCES `share_polls`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `poll_participants_poll_idx` ON `poll_participants` (`poll_id`);--> statement-breakpoint
CREATE UNIQUE INDEX `poll_participants_edit_token_idx` ON `poll_participants` (`edit_token_hash`);--> statement-breakpoint
CREATE TABLE `poll_votes` (
	`participant_id` text NOT NULL,
	`slot_id` text NOT NULL,
	`response` text NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	PRIMARY KEY(`participant_id`, `slot_id`),
	FOREIGN KEY (`participant_id`) REFERENCES `poll_participants`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`slot_id`) REFERENCES `share_slots`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `share_polls` (
	`id` text PRIMARY KEY NOT NULL,
	`created_by` text NOT NULL,
	`title` text NOT NULL,
	`description` text DEFAULT '' NOT NULL,
	`timezone` text NOT NULL,
	`public_token_hash` text NOT NULL,
	`manage_token_hash` text NOT NULL,
	`status` text DEFAULT 'open' NOT NULL,
	`closes_at` text,
	`selected_slot_id` text,
	`version` integer DEFAULT 1 NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`updated_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `share_polls_public_token_idx` ON `share_polls` (`public_token_hash`);--> statement-breakpoint
CREATE UNIQUE INDEX `share_polls_manage_token_idx` ON `share_polls` (`manage_token_hash`);--> statement-breakpoint
CREATE INDEX `share_polls_owner_idx` ON `share_polls` (`created_by`,`created_at`);--> statement-breakpoint
CREATE TABLE `share_slots` (
	`id` text PRIMARY KEY NOT NULL,
	`poll_id` text NOT NULL,
	`label` text DEFAULT '' NOT NULL,
	`starts_at` text NOT NULL,
	`ends_at` text NOT NULL,
	`sort_order` integer NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`poll_id`) REFERENCES `share_polls`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `share_slots_poll_idx` ON `share_slots` (`poll_id`,`sort_order`);--> statement-breakpoint
CREATE UNIQUE INDEX `share_slots_poll_time_idx` ON `share_slots` (`poll_id`,`starts_at`,`ends_at`);