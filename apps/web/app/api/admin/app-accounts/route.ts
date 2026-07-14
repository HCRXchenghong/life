import { desc, eq } from "drizzle-orm";
import { getD1, getDb } from "../../../../db";
import { appAccounts } from "../../../../db/schema";
import {
  consumeAuthRateLimit,
  RateLimitError,
  rateLimitResponse,
} from "../../../../lib/admin-auth";
import { requireAdmin } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import {
  canonicalAccountUsername,
  validateAccountUsername,
  validateStrongPassword,
} from "../../../../lib/security/account-credentials";
import { hashPassword } from "../../../../lib/security/auth-crypto";
import { noStoreJson, requireJsonRequest } from "../../../../lib/security/http";
import { assertAllowedFields, requiredText } from "../../../../lib/security/validation";

const ACTIONS = new Set(["disable", "enable", "reset_password"]);

function publicAccount(record: typeof appAccounts.$inferSelect) {
  return {
    id: record.id,
    username: record.username,
    status: record.status,
    passwordChangeRequired: record.passwordChangeRequired,
    lockedUntil: record.lockedUntil,
    lastLoginAt: record.lastLoginAt,
    createdAt: record.createdAt,
  };
}

export async function GET() {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  const accounts = await getDb()
    .select()
    .from(appAccounts)
    .orderBy(desc(appAccounts.createdAt));
  return noStoreJson({ accounts: accounts.map(publicAccount) });
}

export async function POST(request: Request) {
  const actor = await requireAdmin(request);
  if (actor instanceof Response) return actor;
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;
  try {
    await consumeAuthRateLimit(request, "app_account_admin", actor, 30);
    const payload: unknown = await request.json();
    assertAllowedFields(payload, ["username", "password", "confirmPassword"]);
    const username = validateAccountUsername(payload.username, "App 账号");
    const password = validateStrongPassword(payload.password);
    if (password !== payload.confirmPassword) throw new Error("两次输入的密码不一致");

    const id = crypto.randomUUID();
    const now = new Date().toISOString();
    const digest = await hashPassword(password, "app");
    let created: typeof appAccounts.$inferSelect;
    try {
      [created] = await getDb()
        .insert(appAccounts)
        .values({
          id,
          username,
          usernameCanonical: canonicalAccountUsername(username),
          passwordAlgorithm: digest.algorithm,
          passwordHash: digest.hash,
          passwordSalt: digest.salt,
          passwordIterations: digest.iterations,
          passwordChangeRequired: true,
          status: "active",
          passwordChangedAt: now,
          createdAt: now,
          updatedAt: now,
        })
        .returning();
    } catch {
      const [existing] = await getDb()
        .select({ id: appAccounts.id })
        .from(appAccounts)
        .where(eq(appAccounts.usernameCanonical, canonicalAccountUsername(username)))
        .limit(1);
      if (existing) {
        return noStoreJson(
          { error: { code: "username_unavailable", message: "该 App 账号已存在" } },
          { status: 409 },
        );
      }
      throw new Error("暂时无法创建 App 账号");
    }

    await writeAudit({
      actor,
      action: "app_account.create",
      targetType: "app_account",
      targetId: id,
      outcome: "allowed",
      risk: "high",
      metadata: { passwordChangeRequired: true },
    });
    return noStoreJson({ account: publicAccount(created) }, { status: 201 });
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    const message = error instanceof Error ? error.message : "请求无效";
    const unavailable = message.includes("AUTH_SECRET_MASTER_KEY") || message.includes("not configured");
    return noStoreJson(
      {
        error: {
          code: unavailable ? "auth_not_configured" : "invalid_request",
          message: unavailable ? "App 鉴权尚未配置" : message,
        },
      },
      { status: unavailable ? 503 : 400 },
    );
  }
}

export async function PATCH(request: Request) {
  const actor = await requireAdmin(request);
  if (actor instanceof Response) return actor;
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;
  try {
    await consumeAuthRateLimit(request, "app_account_admin", actor, 30);
    const payload: unknown = await request.json();
    assertAllowedFields(payload, ["id", "action", "password", "confirmPassword"]);
    const id = requiredText(payload.id, "id", 64);
    const action = requiredText(payload.action, "action", 32);
    if (!ACTIONS.has(action)) throw new Error("不支持的账号操作");
    if (action !== "reset_password" && (payload.password !== undefined || payload.confirmPassword !== undefined)) {
      throw new Error("该账号操作不接受密码字段");
    }
    const now = new Date().toISOString();
    const d1 = getD1();

    if (action === "reset_password") {
      const password = validateStrongPassword(payload.password);
      if (password !== payload.confirmPassword) throw new Error("两次输入的密码不一致");
      const digest = await hashPassword(password, "app");
      const [accountResult] = await d1.batch([
        d1.prepare(
          `UPDATE app_accounts
           SET password_algorithm = ?, password_hash = ?, password_salt = ?,
               password_iterations = ?, password_change_required = 1,
               failed_login_count = 0, locked_until = NULL,
               password_changed_at = ?, updated_at = ?
           WHERE id = ?`,
        ).bind(
          digest.algorithm,
          digest.hash,
          digest.salt,
          digest.iterations,
          now,
          now,
          id,
        ),
        d1.prepare(
          "UPDATE app_sessions SET revoked_at = ? WHERE account_id = ? AND revoked_at IS NULL",
        ).bind(now, id),
      ]);
      if ((accountResult.meta.changes ?? 0) !== 1) return accountNotFound();
    } else if (action === "disable") {
      const [accountResult] = await d1.batch([
        d1.prepare(
          "UPDATE app_accounts SET status = 'disabled', updated_at = ? WHERE id = ?",
        ).bind(now, id),
        d1.prepare(
          "UPDATE app_sessions SET revoked_at = ? WHERE account_id = ? AND revoked_at IS NULL",
        ).bind(now, id),
      ]);
      if ((accountResult.meta.changes ?? 0) !== 1) return accountNotFound();
    } else {
      const changed = await getDb()
        .update(appAccounts)
        .set({ status: "active", failedLoginCount: 0, lockedUntil: null, updatedAt: now })
        .where(eq(appAccounts.id, id))
        .returning({ id: appAccounts.id });
      if (changed.length !== 1) return accountNotFound();
    }

    await writeAudit({
      actor,
      action: `app_account.${action}`,
      targetType: "app_account",
      targetId: id,
      outcome: "allowed",
      risk: action === "enable" ? "high" : "critical",
    });
    return noStoreJson({ updated: true });
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    const message = error instanceof Error ? error.message : "请求无效";
    return noStoreJson(
      { error: { code: "invalid_request", message } },
      { status: 400 },
    );
  }
}

function accountNotFound(): Response {
  return noStoreJson(
    { error: { code: "not_found", message: "App 账号不存在" } },
    { status: 404 },
  );
}
