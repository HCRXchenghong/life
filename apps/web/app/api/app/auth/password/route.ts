import { eq } from "drizzle-orm";
import { getD1, getDb } from "../../../../../db";
import { appAccounts } from "../../../../../db/schema";
import {
  clearAuthRateLimit,
  consumeAuthRateLimit,
  RateLimitError,
  rateLimitResponse,
} from "../../../../../lib/admin-auth";
import { createAppSession, requireAppIdentity } from "../../../../../lib/app-auth";
import { writeAudit } from "../../../../../lib/audit";
import { validateStrongPassword } from "../../../../../lib/security/account-credentials";
import { hashPassword, verifyPassword } from "../../../../../lib/security/auth-crypto";
import { noStoreJson, requireJsonRequest } from "../../../../../lib/security/http";
import { assertAllowedFields } from "../../../../../lib/security/validation";

export async function POST(request: Request) {
  const identity = await requireAppIdentity(request);
  if (identity instanceof Response) return identity;
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;
  try {
    await consumeAuthRateLimit(request, "app_password", identity.accountId, 8);
    const payload: unknown = await request.json();
    assertAllowedFields(payload, ["currentPassword", "newPassword"]);
    const currentPassword = typeof payload.currentPassword === "string" ? payload.currentPassword : "";
    const newPassword = validateStrongPassword(payload.newPassword);
    if (currentPassword === newPassword) throw new Error("新密码不能与当前密码相同");

    const [account] = await getDb()
      .select()
      .from(appAccounts)
      .where(eq(appAccounts.id, identity.accountId))
      .limit(1);
    const valid = Boolean(
      account &&
        await verifyPassword(currentPassword, {
          algorithm: account.passwordAlgorithm as Parameters<typeof verifyPassword>[1]["algorithm"],
          hash: account.passwordHash,
          salt: account.passwordSalt,
          iterations: account.passwordIterations,
        }),
    );
    if (!account || !valid) {
      await writeAudit({
        actor: `app:${identity.accountId}`,
        action: "app.password.change",
        targetType: "app_account",
        targetId: identity.accountId,
        outcome: "denied",
        risk: "critical",
        metadata: { reason: "invalid_current_password" },
      });
      return noStoreJson(
        { error: { code: "invalid_credentials", message: "当前密码不正确" } },
        { status: 401 },
      );
    }

    const digest = await hashPassword(newPassword, "app");
    const now = new Date().toISOString();
    const d1 = getD1();
    const [accountResult] = await d1.batch([
      d1.prepare(
        `UPDATE app_accounts
         SET password_algorithm = ?, password_hash = ?, password_salt = ?,
             password_iterations = ?, password_change_required = 0,
             failed_login_count = 0, locked_until = NULL,
             password_changed_at = ?, updated_at = ?
         WHERE id = ? AND status = 'active'`,
      ).bind(
        digest.algorithm,
        digest.hash,
        digest.salt,
        digest.iterations,
        now,
        now,
        identity.accountId,
      ),
      d1.prepare(
        "UPDATE app_sessions SET revoked_at = ? WHERE account_id = ? AND revoked_at IS NULL",
      ).bind(now, identity.accountId),
    ]);
    if ((accountResult.meta.changes ?? 0) !== 1) {
      return noStoreJson(
        { error: { code: "account_unavailable", message: "账号当前不可用" } },
        { status: 409 },
      );
    }
    const tokens = await createAppSession(identity.accountId, identity.deviceName);
    await clearAuthRateLimit(request, "app_password", identity.accountId);
    await writeAudit({
      actor: `app:${identity.accountId}`,
      action: "app.password.change",
      targetType: "app_account",
      targetId: identity.accountId,
      outcome: "allowed",
      risk: "critical",
    });
    return noStoreJson({
      account: {
        id: identity.accountId,
        username: identity.username,
        passwordChangeRequired: false,
      },
      tokens,
    });
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    const message = error instanceof Error ? error.message : "修改密码失败";
    return noStoreJson(
      { error: { code: "invalid_request", message } },
      { status: 400 },
    );
  }
}
