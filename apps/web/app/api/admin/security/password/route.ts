import { getD1 } from "../../../../../db";
import {
  clearAuthRateLimit,
  consumeAuthRateLimit,
  RateLimitError,
  rateLimitResponse,
} from "../../../../../lib/admin-auth";
import { requireAdminIdentity } from "../../../../../lib/api-auth";
import { verifyAdminStepUp } from "../../../../../lib/admin-security";
import { writeAudit } from "../../../../../lib/audit";
import { validateStrongPassword } from "../../../../../lib/security/account-credentials";
import { hashPassword } from "../../../../../lib/security/auth-crypto";
import {
  clearPrivateCookie,
  noStoreJson,
  requireJsonRequest,
} from "../../../../../lib/security/http";
import { assertAllowedFields } from "../../../../../lib/security/validation";

export async function POST(request: Request) {
  const identity = await requireAdminIdentity(request);
  if (identity instanceof Response) return identity;
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;

  try {
    await consumeAuthRateLimit(request, "admin_security", `${identity.id}:password`, 8);
    const payload: unknown = await request.json();
    assertAllowedFields(payload, [
      "currentPassword",
      "currentCode",
      "newPassword",
      "confirmPassword",
    ]);
    const currentPassword = typeof payload.currentPassword === "string" ? payload.currentPassword : "";
    const currentCode = typeof payload.currentCode === "string" ? payload.currentCode.trim() : "";
    const newPassword = validateStrongPassword(payload.newPassword);
    if (newPassword !== payload.confirmPassword) throw new Error("两次输入的新密码不一致");
    if (currentPassword === newPassword) throw new Error("新密码不能与当前密码相同");

    const challenge = await verifyAdminStepUp(identity, currentPassword, currentCode);
    if (!challenge) {
      await writeAudit({
        actor: identity.actor,
        action: "admin.password.change",
        targetType: "admin_account",
        targetId: identity.id,
        outcome: "denied",
        risk: "critical",
        metadata: { reason: "invalid_step_up" },
      });
      return invalidCredentials();
    }

    const digest = await hashPassword(newPassword);
    const now = new Date().toISOString();
    const d1 = getD1();
    const [accountResult] = await d1.batch([
      d1.prepare(
        `UPDATE admin_accounts
         SET password_algorithm = ?, password_hash = ?, password_salt = ?,
             password_iterations = ?, totp_last_counter = ?,
             failed_login_count = 0, locked_until = NULL,
             password_changed_at = ?, updated_at = ?
         WHERE id = ? AND status = 'active'
           AND (totp_last_counter IS NULL OR totp_last_counter < ?)`,
      ).bind(
        digest.algorithm,
        digest.hash,
        digest.salt,
        digest.iterations,
        challenge.acceptedCounter,
        now,
        now,
        identity.id,
        challenge.acceptedCounter,
      ),
      d1.prepare(
        "UPDATE admin_sessions SET revoked_at = ? WHERE admin_id = ? AND revoked_at IS NULL",
      ).bind(now, identity.id),
    ]);
    if ((accountResult.meta.changes ?? 0) !== 1) {
      await writeAudit({
        actor: identity.actor,
        action: "admin.password.change",
        targetType: "admin_account",
        targetId: identity.id,
        outcome: "denied",
        risk: "critical",
        metadata: { reason: "step_up_replayed" },
      });
      return noStoreJson(
        { error: { code: "security_conflict", message: "验证状态已变化，请重新登录后再试" } },
        { status: 409 },
      );
    }

    await clearAuthRateLimit(request, "admin_security", `${identity.id}:password`);
    await writeAudit({
      actor: identity.actor,
      action: "admin.password.change",
      targetType: "admin_account",
      targetId: identity.id,
      outcome: "allowed",
      risk: "critical",
    });
    const response = noStoreJson({ reauthenticate: true });
    response.headers.append("set-cookie", clearPrivateCookie(request, "session"));
    return response;
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    const message = error instanceof Error ? error.message : "修改密码失败";
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

function invalidCredentials(): Response {
  return noStoreJson(
    { error: { code: "invalid_credentials", message: "当前密码或验证码不正确，验证码不可重复使用" } },
    { status: 401 },
  );
}
