import { sql } from "drizzle-orm";
import {
  index,
  integer,
  primaryKey,
  sqliteTable,
  text,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";

const timestamps = {
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
};

export const mobileApiTokens = sqliteTable(
  "mobile_api_tokens",
  {
    id: text("id").primaryKey(),
    ownerEmail: text("owner_email").notNull(),
    name: text("name").notNull(),
    tokenHash: text("token_hash").notNull(),
    tokenHint: text("token_hint").notNull(),
    expiresAt: text("expires_at"),
    lastUsedAt: text("last_used_at"),
    revokedAt: text("revoked_at"),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [
    uniqueIndex("mobile_api_tokens_hash_idx").on(table.tokenHash),
    index("mobile_api_tokens_owner_idx").on(table.ownerEmail, table.createdAt),
  ],
);

export const adminAccounts = sqliteTable(
  "admin_accounts",
  {
    id: text("id").primaryKey(),
    singletonKey: integer("singleton_key").notNull().default(1),
    username: text("username").notNull(),
    usernameCanonical: text("username_canonical").notNull(),
    passwordAlgorithm: text("password_algorithm").notNull(),
    passwordHash: text("password_hash").notNull(),
    passwordSalt: text("password_salt").notNull(),
    passwordIterations: integer("password_iterations").notNull(),
    totpSecretCiphertext: text("totp_secret_ciphertext").notNull(),
    totpSecretNonce: text("totp_secret_nonce").notNull(),
    totpLastCounter: integer("totp_last_counter"),
    status: text("status", { enum: ["pending", "active", "disabled"] })
      .notNull()
      .default("pending"),
    enrollmentTokenHash: text("enrollment_token_hash"),
    enrollmentExpiresAt: text("enrollment_expires_at"),
    failedLoginCount: integer("failed_login_count").notNull().default(0),
    lockedUntil: text("locked_until"),
    activatedAt: text("activated_at"),
    lastLoginAt: text("last_login_at"),
    passwordChangedAt: text("password_changed_at").notNull(),
    ...timestamps,
  },
  (table) => [
    uniqueIndex("admin_accounts_singleton_idx").on(table.singletonKey),
    uniqueIndex("admin_accounts_username_idx").on(table.usernameCanonical),
    index("admin_accounts_status_idx").on(table.status),
  ],
);

export const adminSessions = sqliteTable(
  "admin_sessions",
  {
    id: text("id").primaryKey(),
    adminId: text("admin_id")
      .notNull()
      .references(() => adminAccounts.id, { onDelete: "cascade" }),
    tokenHash: text("token_hash").notNull(),
    userAgentHash: text("user_agent_hash"),
    expiresAt: text("expires_at").notNull(),
    lastSeenAt: text("last_seen_at").notNull(),
    revokedAt: text("revoked_at"),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [
    uniqueIndex("admin_sessions_token_idx").on(table.tokenHash),
    index("admin_sessions_admin_idx").on(table.adminId, table.createdAt),
    index("admin_sessions_expiry_idx").on(table.expiresAt),
  ],
);

export const authRateLimits = sqliteTable(
  "auth_rate_limits",
  {
    bucketKey: text("bucket_key").primaryKey(),
    action: text("action").notNull(),
    windowStartedAt: text("window_started_at").notNull(),
    attempts: integer("attempts").notNull().default(0),
    blockedUntil: text("blocked_until"),
    updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [index("auth_rate_limits_updated_idx").on(table.updatedAt)],
);

export const aiProviderConfigs = sqliteTable(
  "ai_provider_configs",
  {
    id: text("id").primaryKey(),
    ownerEmail: text("owner_email").notNull(),
    name: text("name").notNull(),
    kind: text("kind", {
      enum: ["openai_responses", "openai_compatible", "anthropic_compatible"],
    }).notNull(),
    baseUrl: text("base_url").notNull(),
    textModel: text("text_model").notNull(),
    imageModel: text("image_model"),
    apiKeyCiphertext: text("api_key_ciphertext").notNull(),
    apiKeyNonce: text("api_key_nonce").notNull(),
    apiKeyHint: text("api_key_hint").notNull(),
    enabled: integer("enabled", { mode: "boolean" }).notNull().default(true),
    ...timestamps,
  },
  (table) => [
    index("ai_provider_owner_idx").on(table.ownerEmail),
    uniqueIndex("ai_provider_owner_name_idx").on(table.ownerEmail, table.name),
  ],
);

export const aiRuns = sqliteTable(
  "ai_runs",
  {
    id: text("id").primaryKey(),
    ownerEmail: text("owner_email").notNull(),
    providerConfigId: text("provider_config_id")
      .notNull()
      .references(() => aiProviderConfigs.id, { onDelete: "restrict" }),
    kind: text("kind", { enum: ["assistant", "image", "provider_test"] }).notNull(),
    status: text("status", {
      enum: ["queued", "running", "succeeded", "failed", "cancelled"],
    }).notNull(),
    model: text("model").notNull(),
    requestDigest: text("request_digest").notNull(),
    responseId: text("response_id"),
    errorCode: text("error_code"),
    errorMessage: text("error_message"),
    startedAt: text("started_at"),
    completedAt: text("completed_at"),
    ...timestamps,
  },
  (table) => [index("ai_runs_owner_created_idx").on(table.ownerEmail, table.createdAt)],
);

export const auditEvents = sqliteTable(
  "audit_events",
  {
    id: text("id").primaryKey(),
    actor: text("actor").notNull(),
    action: text("action").notNull(),
    targetType: text("target_type").notNull(),
    targetId: text("target_id"),
    outcome: text("outcome", { enum: ["allowed", "denied", "failed"] }).notNull(),
    risk: text("risk", { enum: ["read_only", "low", "medium", "high", "critical"] })
      .notNull()
      .default("low"),
    requestId: text("request_id"),
    metadataJson: text("metadata_json").notNull().default("{}"),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [index("audit_actor_created_idx").on(table.actor, table.createdAt)],
);

export const sharePolls = sqliteTable(
  "share_polls",
  {
    id: text("id").primaryKey(),
    createdBy: text("created_by").notNull(),
    title: text("title").notNull(),
    description: text("description").notNull().default(""),
    timezone: text("timezone").notNull(),
    publicTokenHash: text("public_token_hash").notNull(),
    manageTokenHash: text("manage_token_hash").notNull(),
    status: text("status", { enum: ["open", "closed", "cancelled", "expired"] })
      .notNull()
      .default("open"),
    closesAt: text("closes_at"),
    selectedSlotId: text("selected_slot_id"),
    version: integer("version").notNull().default(1),
    ...timestamps,
  },
  (table) => [
    uniqueIndex("share_polls_public_token_idx").on(table.publicTokenHash),
    uniqueIndex("share_polls_manage_token_idx").on(table.manageTokenHash),
    index("share_polls_owner_idx").on(table.createdBy, table.createdAt),
  ],
);

export const shareSlots = sqliteTable(
  "share_slots",
  {
    id: text("id").primaryKey(),
    pollId: text("poll_id")
      .notNull()
      .references(() => sharePolls.id, { onDelete: "cascade" }),
    label: text("label").notNull().default(""),
    startsAt: text("starts_at").notNull(),
    endsAt: text("ends_at").notNull(),
    sortOrder: integer("sort_order").notNull(),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [
    index("share_slots_poll_idx").on(table.pollId, table.sortOrder),
    uniqueIndex("share_slots_poll_time_idx").on(table.pollId, table.startsAt, table.endsAt),
  ],
);

export const pollParticipants = sqliteTable(
  "poll_participants",
  {
    id: text("id").primaryKey(),
    pollId: text("poll_id")
      .notNull()
      .references(() => sharePolls.id, { onDelete: "cascade" }),
    displayName: text("display_name").notNull(),
    editTokenHash: text("edit_token_hash").notNull(),
    ...timestamps,
  },
  (table) => [
    index("poll_participants_poll_idx").on(table.pollId),
    uniqueIndex("poll_participants_edit_token_idx").on(table.editTokenHash),
  ],
);

export const pollVotes = sqliteTable(
  "poll_votes",
  {
    participantId: text("participant_id")
      .notNull()
      .references(() => pollParticipants.id, { onDelete: "cascade" }),
    slotId: text("slot_id")
      .notNull()
      .references(() => shareSlots.id, { onDelete: "cascade" }),
    response: text("response", { enum: ["yes", "maybe", "no"] }).notNull(),
    updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [primaryKey({ columns: [table.participantId, table.slotId] })],
);

export const generatedAssets = sqliteTable(
  "generated_assets",
  {
    id: text("id").primaryKey(),
    ownerEmail: text("owner_email").notNull(),
    providerConfigId: text("provider_config_id")
      .notNull()
      .references(() => aiProviderConfigs.id, { onDelete: "restrict" }),
    aiRunId: text("ai_run_id").references(() => aiRuns.id, { onDelete: "set null" }),
    r2Key: text("r2_key").notNull(),
    promptDigest: text("prompt_digest").notNull(),
    contentType: text("content_type").notNull(),
    byteSize: integer("byte_size").notNull(),
    width: integer("width"),
    height: integer("height"),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [
    uniqueIndex("generated_assets_r2_key_idx").on(table.r2Key),
    index("generated_assets_owner_idx").on(table.ownerEmail, table.createdAt),
  ],
);
