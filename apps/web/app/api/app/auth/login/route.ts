import { and, eq } from "drizzle-orm";
import { getD1, getDb } from "../../../../../db";
import { appAccounts } from "../../../../../db/schema";
import {
  clearAuthRateLimit,
  consumeAuthRateLimit,
  RateLimitError,
  rateLimitResponse,
} from "../../../../../lib/admin-auth";
import { createAppSession } from "../../../../../lib/app-auth";
import { writeAudit } from "../../../../../lib/audit";
import {
  canonicalAccountUsername,
  validateDeviceName,
} from "../../../../../lib/security/account-credentials";
import {
  type PasswordAlgorithm,
  verifyPassword,
} from "../../../../../lib/security/auth-crypto";
import { noStoreJson, requireJsonRequest } from "../../../../../lib/security/http";
import { assertAllowedFields } from "../../../../../lib/security/validation";

const DUMMY_PASSWORD = {
  algorithm: "pbkdf2-sha256-app-v1" as const,
  hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
  salt: "AAAAAAAAAAAAAAAAAAAAAA==",
  iterations: 600_000,
};

export async function POST(request: Request) {
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;
  try {
    const payload: unknown = await request.json();
    assertAllowedFields(payload, ["username", "password", "deviceName"]);
    const username = typeof payload.username === "string" ? payload.username.trim() : "";
    const password = typeof payload.password === "string" && payload.password.length <= 128
      ? payload.password
      : "";
    const deviceName = validateDeviceName(payload.deviceName);
    await consumeAuthRateLimit(request, "app_login", username || "unknown", 10);

    const [account] = username.length <= 32
      ? await getDb()
          .select()
          .from(appAccounts)
          .where(eq(appAccounts.usernameCanonical, canonicalAccountUsername(username)))
          .limit(1)
      : [];
    const passwordOk = await verifyPassword(
      password,
      account
        ? {
            algorithm: account.passwordAlgorithm as PasswordAlgorithm,
            hash: account.passwordHash,
            salt: account.passwordSalt,
            iterations: account.passwordIterations,
          }
        : DUMMY_PASSWORD,
    );
    const now = Date.now();
    const locked = Boolean(account?.lockedUntil && new Date(account.lockedUntil).getTime() > now);
    if (!account || account.status !== "active" || !passwordOk || locked) {
      if (account) await recordFailedAppLogin(account.id);
      await writeAudit({
        actor: account ? `app:${account.id}` : "app:unknown",
        action: "app.login",
        targetType: "app_session",
        targetId: account?.id,
        outcome: "denied",
        risk: "high",
        metadata: { reason: locked ? "locked" : "invalid_credentials" },
      });
      return invalidCredentials();
    }

    const nowIso = new Date(now).toISOString();
    const changed = await getDb()
      .update(appAccounts)
      .set({
        failedLoginCount: 0,
        lockedUntil: null,
        lastLoginAt: nowIso,
        updatedAt: nowIso,
      })
      .where(and(eq(appAccounts.id, account.id), eq(appAccounts.status, "active")))
      .returning({ id: appAccounts.id });
    if (changed.length !== 1) return invalidCredentials();

    const tokens = await createAppSession(account.id, deviceName);
    await clearAuthRateLimit(request, "app_login", username);
    await writeAudit({
      actor: `app:${account.id}`,
      action: "app.login",
      targetType: "app_session",
      outcome: "allowed",
      risk: "high",
    });
    return noStoreJson({
      account: {
        id: account.id,
        username: account.username,
        passwordChangeRequired: account.passwordChangeRequired,
      },
      tokens,
    });
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    return noStoreJson(
      { error: { code: "login_failed", message: "登录失败，请稍后重试" } },
      { status: 500 },
    );
  }
}

async function recordFailedAppLogin(accountId: string): Promise<void> {
  const now = new Date();
  await getD1()
    .prepare(
      `UPDATE app_accounts
       SET failed_login_count = failed_login_count + 1,
           locked_until = CASE WHEN failed_login_count + 1 >= 5 THEN ? ELSE locked_until END,
           updated_at = ?
       WHERE id = ?`,
    )
    .bind(
      new Date(now.getTime() + 15 * 60 * 1000).toISOString(),
      now.toISOString(),
      accountId,
    )
    .run();
}

function invalidCredentials(): Response {
  return noStoreJson(
    { error: { code: "invalid_credentials", message: "账号或密码不正确" } },
    { status: 401 },
  );
}
