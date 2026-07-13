import { and, eq } from "drizzle-orm";
import { getDb } from "../../../../../db";
import { adminAccounts } from "../../../../../db/schema";
import {
  clearAuthRateLimit,
  consumeAuthRateLimit,
  createAdminSession,
  getPendingEnrollment,
  RateLimitError,
  rateLimitResponse,
} from "../../../../../lib/admin-auth";
import { writeAudit } from "../../../../../lib/audit";
import {
  decryptAuthSecret,
  verifyTotp,
} from "../../../../../lib/security/auth-crypto";
import {
  clearPrivateCookie,
  noStoreJson,
  requireSameOriginMutation,
  serializePrivateCookie,
} from "../../../../../lib/security/http";

export async function POST(request: Request) {
  const csrfFailure = requireSameOriginMutation(request);
  if (csrfFailure) return csrfFailure;
  try {
    const payload = (await request.json()) as Record<string, unknown>;
    const code = typeof payload.code === "string" ? payload.code.trim() : "";
    await consumeAuthRateLimit(request, "totp_enrollment", "verify", 8);
    const account = await getPendingEnrollment(request.headers.get("cookie"));
    if (!account) {
      return noStoreJson(
        { error: { code: "enrollment_expired", message: "初始化会话已失效，请重新开始" } },
        { status: 401 },
      );
    }
    const secret = await decryptAuthSecret(
      { ciphertext: account.totpSecretCiphertext, nonce: account.totpSecretNonce },
      `admin-totp:${account.id}`,
    );
    const acceptedCounter = await verifyTotp(secret, code, account.totpLastCounter);
    if (acceptedCounter === null) {
      await writeAudit({
        actor: "system:bootstrap",
        action: "admin.enrollment.verify",
        targetType: "admin_account",
        targetId: account.id,
        outcome: "denied",
        risk: "critical",
        metadata: { reason: "invalid_totp" },
      });
      return noStoreJson(
        { error: { code: "invalid_code", message: "验证码不正确或已使用" } },
        { status: 401 },
      );
    }

    const now = new Date().toISOString();
    const activated = await getDb()
      .update(adminAccounts)
      .set({
        status: "active",
        totpLastCounter: acceptedCounter,
        enrollmentTokenHash: null,
        enrollmentExpiresAt: null,
        activatedAt: now,
        updatedAt: now,
      })
      .where(and(eq(adminAccounts.id, account.id), eq(adminAccounts.status, "pending")))
      .returning({ id: adminAccounts.id });
    if (activated.length !== 1) {
      return noStoreJson(
        { error: { code: "enrollment_conflict", message: "初始化状态已变化，请重新登录" } },
        { status: 409 },
      );
    }

    const session = await createAdminSession(account.id, request.headers.get("user-agent"));
    await clearAuthRateLimit(request, "totp_enrollment", "verify");
    await writeAudit({
      actor: `admin:${account.id}`,
      action: "admin.enrollment.completed",
      targetType: "admin_account",
      targetId: account.id,
      outcome: "allowed",
      risk: "critical",
    });
    const response = noStoreJson({ next: "/admin" });
    response.headers.append(
      "set-cookie",
      serializePrivateCookie(request, "session", session.token, session.maxAgeSeconds),
    );
    response.headers.append("set-cookie", clearPrivateCookie(request, "enrollment"));
    return response;
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    return noStoreJson(
      { error: { code: "verification_failed", message: "验证失败，请稍后重试" } },
      { status: 500 },
    );
  }
}
