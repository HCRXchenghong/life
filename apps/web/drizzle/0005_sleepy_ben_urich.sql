CREATE TABLE `admin_totp_rebindings` (
	`id` text PRIMARY KEY NOT NULL,
	`admin_id` text NOT NULL,
	`token_hash` text NOT NULL,
	`secret_ciphertext` text NOT NULL,
	`secret_nonce` text NOT NULL,
	`expires_at` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	FOREIGN KEY (`admin_id`) REFERENCES `admin_accounts`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `admin_totp_rebindings_admin_idx` ON `admin_totp_rebindings` (`admin_id`);--> statement-breakpoint
CREATE UNIQUE INDEX `admin_totp_rebindings_token_idx` ON `admin_totp_rebindings` (`token_hash`);--> statement-breakpoint
CREATE INDEX `admin_totp_rebindings_expiry_idx` ON `admin_totp_rebindings` (`expires_at`);