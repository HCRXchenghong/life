import { and, eq, isNull, lt, or } from "drizzle-orm";
import { getD1, getDb } from "../../../../db";
import { adminAccounts } from "../../../../db/schema";
import {
  clearAuthRateLimit,
  consumeAuthRateLimit,
  createAdminSession,
  RateLimitError,
  rateLimitResponse,
} from "../../../../lib/admin-auth";
import { writeAudit } from "../../../../lib/audit";
import {
  decryptAuthSecret,
  verifyPassword,
  verifyTotp,
} from "../../../../lib/security/auth-crypto";
import {
  noStoreJson,
  requireSameOriginMutation,
  serializePrivateCookie,
} from "../../../../lib/security/http";

const DUMMY_PASSWORD = {
  algorithm: "pbkdf2-sha256" as const,
  hash: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
  salt: "AAAAAAAAAAAAAAAAAAAAAA==",
  iterations: 600_000,
};

export async function POST(request: Request) {
  const csrfFailure = requireSameOriginMutation(request);
  if (csrfFailure) return csrfFailure;
  try {
    const payload = (await request.json()) as Record<string, unknown>;
    const username = typeof payload.username === "string" ? payload.username.trim() : "";
    const password = typeof payload.password === "string" ? payload.password : "";
    const code = typeof payload.code === "string" ? payload.code.trim() : "";
    await consumeAuthRateLimit(request, "login", username || "unknown", 10);

    const [account] = await getDb()
      .select()
      .from(adminAccounts)
      .where(eq(adminAccounts.usernameCanonical, username.toLowerCase()))
      .limit(1);
    const passwordOk = await verifyPassword(
      password,
      account
        ? {
            algorithm: account.passwordAlgorithm as "pbkdf2-sha256",
            hash: account.passwordHash,
            salt: account.passwordSalt,
            iterations: account.passwordIterations,
          }
        : DUMMY_PASSWORD,
    );
    const now = Date.now();
    const locked = Boolean(account?.lockedUntil && new Date(account.lockedUntil).getTime() > now);

    let acceptedCounter: number | null = null;
    if (account && account.status === "active" && passwordOk && !locked) {
      const secret = await decryptAuthSecret(
        { ciphertext: account.totpSecretCiphertext, nonce: account.totpSecretNonce },
        `admin-totp:${account.id}`,
      );
      acceptedCounter = await verifyTotp(secret, code, account.totpLastCounter);
    }

    if (!account || account.status !== "active" || !passwordOk || locked || acceptedCounter === null) {
      if (account) await recordFailedLogin(account.id);
      await writeAudit({
        actor: account ? `admin:${account.id}` : "admin:unknown",
        action: "admin.login",
        targetType: "admin_session",
        targetId: account?.id,
        outcome: "denied",
        risk: "high",
        metadata: { reason: locked ? "locked" : "invalid_credentials" },
      });
      return noStoreJson(
        { error: { code: "invalid_credentials", message: "账号、密码或验证码不正确" } },
        { status: 401 },
      );
    }

    const nowIso = new Date(now).toISOString();
    const updated = await getDb()
      .update(adminAccounts)
      .set({
        totpLastCounter: acceptedCounter,
        failedLoginCount: 0,
        lockedUntil: null,
        lastLoginAt: nowIso,
        updatedAt: nowIso,
      })
      .where(
        and(
          eq(adminAccounts.id, account.id),
          eq(adminAccounts.status, "active"),
          or(isNull(adminAccounts.totpLastCounter), lt(adminAccounts.totpLastCounter, acceptedCounter)),
        ),
      )
      .returning({ id: adminAccounts.id });
    if (updated.length !== 1) {
      return noStoreJson(
        { error: { code: "invalid_credentials", message: "账号、密码或验证码不正确" } },
        { status: 401 },
      );
    }

    const session = await createAdminSession(account.id, request.headers.get("user-agent"));
    await clearAuthRateLimit(request, "login", username);
    await writeAudit({
      actor: `admin:${account.id}`,
      action: "admin.login",
      targetType: "admin_session",
      outcome: "allowed",
      risk: "high",
    });
    const response = noStoreJson({ next: "/admin" });
    response.headers.append(
      "set-cookie",
      serializePrivateCookie(request, "session", session.token, session.maxAgeSeconds),
    );
    return response;
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    return noStoreJson(
      { error: { code: "login_failed", message: "登录失败，请稍后重试" } },
      { status: 500 },
    );
  }
}

async function recordFailedLogin(accountId: string): Promise<void> {
  const now = new Date();
  await getD1()
    .prepare(
      `UPDATE admin_accounts
       SET failed_login_count = failed_login_count + 1,
           locked_until = CASE
             WHEN failed_login_count + 1 >= 5 THEN ?
             ELSE locked_until
           END,
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
