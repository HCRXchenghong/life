import { eq } from "drizzle-orm";
import { getDb } from "../../../../db";
import { adminAccounts } from "../../../../db/schema";
import {
  consumeAuthRateLimit,
  getBootstrapState,
  getPendingEnrollment,
  RateLimitError,
  rateLimitResponse,
} from "../../../../lib/admin-auth";
import { writeAudit } from "../../../../lib/audit";
import { authorizeBootstrap } from "../../../../lib/bootstrap-auth";
import {
  createTotpSecret,
  encryptAuthSecret,
  hashOpaqueToken,
  hashPassword,
  randomToken,
} from "../../../../lib/security/auth-crypto";
import {
  clearPrivateCookie,
  noStoreJson,
  requireJsonRequest,
  requireSameOriginMutation,
  serializePrivateCookie,
} from "../../../../lib/security/http";
import {
  validateAccountUsername,
  validateStrongPassword,
} from "../../../../lib/security/account-credentials";
import { assertAllowedFields } from "../../../../lib/security/validation";

const ENROLLMENT_SECONDS = 10 * 60;

export async function DELETE(request: Request) {
  const csrfFailure = requireSameOriginMutation(request);
  if (csrfFailure) return csrfFailure;
  const account = await getPendingEnrollment(request.headers.get("cookie"));
  if (!account) {
    return noStoreJson(
      { error: { code: "enrollment_expired", message: "初始化会话已失效" } },
      { status: 401 },
    );
  }
  await getDb().delete(adminAccounts).where(eq(adminAccounts.id, account.id));
  await writeAudit({
    actor: "system:bootstrap",
    action: "admin.enrollment.cancelled",
    targetType: "admin_account",
    targetId: account.id,
    outcome: "allowed",
    risk: "critical",
  });
  const response = noStoreJson({ next: "/admin" });
  response.headers.append("set-cookie", clearPrivateCookie(request, "enrollment"));
  return response;
}

export async function POST(request: Request) {
  const csrfFailure = requireSameOriginMutation(request);
  if (csrfFailure) return csrfFailure;
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;

  const bootstrapAuthorization = authorizeBootstrap(
    request.headers,
    new URL(request.url).hostname,
  );
  if (!bootstrapAuthorization.allowed) {
    const misconfigured = bootstrapAuthorization.reason === "allowlist_missing";
    return noStoreJson(
      {
        error: {
          code: misconfigured ? "bootstrap_not_configured" : "bootstrap_forbidden",
          message: misconfigured ? "管理员初始化白名单尚未配置" : "当前身份无权初始化后台",
        },
      },
      { status: misconfigured ? 503 : 403 },
    );
  }

  try {
    const payload: unknown = await request.json();
    assertAllowedFields(payload, ["username", "password", "confirmPassword"]);
    const username = validateAccountUsername(payload.username, "管理员账号");
    const password = validateStrongPassword(payload.password);
    if (password !== payload.confirmPassword) throw new Error("两次输入的密码不一致");

    await consumeAuthRateLimit(request, "setup", username, 5);
    const state = await getBootstrapState(request.headers.get("cookie"));
    if (state.kind !== "uninitialized") {
      return noStoreJson(
        { error: { code: "setup_unavailable", message: "后台已初始化或正在初始化" } },
        { status: 409 },
      );
    }

    const id = crypto.randomUUID();
    const passwordDigest = await hashPassword(password);
    const totpSecret = createTotpSecret();
    const totpEnvelope = await encryptAuthSecret(totpSecret, `admin-totp:${id}`);
    const enrollmentToken = randomToken();
    const now = new Date();
    const expiresAt = new Date(now.getTime() + ENROLLMENT_SECONDS * 1000).toISOString();

    try {
      await getDb().insert(adminAccounts).values({
        id,
        singletonKey: 1,
        username,
        usernameCanonical: username.toLowerCase(),
        passwordAlgorithm: passwordDigest.algorithm,
        passwordHash: passwordDigest.hash,
        passwordSalt: passwordDigest.salt,
        passwordIterations: passwordDigest.iterations,
        totpSecretCiphertext: totpEnvelope.ciphertext,
        totpSecretNonce: totpEnvelope.nonce,
        status: "pending",
        enrollmentTokenHash: await hashOpaqueToken(enrollmentToken),
        enrollmentExpiresAt: expiresAt,
        passwordChangedAt: now.toISOString(),
        createdAt: now.toISOString(),
        updatedAt: now.toISOString(),
      });
    } catch {
      const [existing] = await getDb().select({ id: adminAccounts.id }).from(adminAccounts).limit(1);
      if (existing) {
        return noStoreJson(
          { error: { code: "setup_unavailable", message: "后台已初始化或正在初始化" } },
          { status: 409 },
        );
      }
      throw new Error("暂时无法创建管理员，请稍后重试");
    }

    await writeAudit({
      actor: bootstrapAuthorization.actor,
      action: "admin.enrollment.started",
      targetType: "admin_account",
      targetId: id,
      outcome: "allowed",
      risk: "critical",
      metadata: { expiresInSeconds: ENROLLMENT_SECONDS },
    });

    const response = noStoreJson(
      { next: "/admin/setup/2fa" },
      { status: 201 },
    );
    response.headers.append(
      "set-cookie",
      serializePrivateCookie(request, "enrollment", enrollmentToken, ENROLLMENT_SECONDS),
    );
    return response;
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    const message = error instanceof Error ? error.message : "请求无效";
    const configurationFailure = message.includes("AUTH_SECRET_MASTER_KEY") || message.includes("not configured");
    return noStoreJson(
      {
        error: {
          code: configurationFailure ? "auth_not_configured" : "invalid_request",
          message: configurationFailure ? "管理员鉴权尚未配置" : message,
        },
      },
      { status: configurationFailure ? 503 : 400 },
    );
  }
}
