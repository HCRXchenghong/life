import { and, eq, isNull, lt, or } from "drizzle-orm";
import { getD1, getDb } from "../../../../../db";
import { adminAccounts, adminTotpRebindings } from "../../../../../db/schema";
import {
  clearAuthRateLimit,
  consumeAuthRateLimit,
  RateLimitError,
  rateLimitResponse,
} from "../../../../../lib/admin-auth";
import type { AdminIdentity } from "../../../../../lib/admin-auth";
import { requireAdminIdentity } from "../../../../../lib/api-auth";
import { verifyAdminStepUp } from "../../../../../lib/admin-security";
import { writeAudit } from "../../../../../lib/audit";
import {
  createTotpSecret,
  createTotpUri,
  decryptAuthSecret,
  encryptAuthSecret,
  hashOpaqueToken,
  randomToken,
  verifyTotp,
} from "../../../../../lib/security/auth-crypto";
import {
  clearPrivateCookie,
  cookieNames,
  noStoreJson,
  readCookie,
  requireJsonRequest,
  serializePrivateCookie,
} from "../../../../../lib/security/http";
import { assertAllowedFields } from "../../../../../lib/security/validation";

const REBIND_SECONDS = 10 * 60;

export async function POST(request: Request) {
  const identity = await requireAdminIdentity(request);
  if (identity instanceof Response) return identity;
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;

  try {
    const payload: unknown = await request.json();
    assertAllowedFields(payload, ["action", "currentPassword", "currentCode", "code"]);
    const action = typeof payload.action === "string" ? payload.action : "";
    if (action === "start") {
      assertAllowedFields(payload, ["action", "currentPassword", "currentCode"]);
      return await startRebinding(request, identity, payload);
    }
    if (action === "verify") {
      assertAllowedFields(payload, ["action", "code"]);
      return await verifyRebinding(request, identity, payload);
    }
    return noStoreJson(
      { error: { code: "invalid_request", message: "不支持的双重验证操作" } },
      { status: 400 },
    );
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    const message = error instanceof Error ? error.message : "双重验证操作失败";
    const configurationFailure = message.includes("AUTH_SECRET_MASTER_KEY") || message.includes("not configured");
    return noStoreJson(
      {
        error: {
          code: configurationFailure ? "auth_not_configured" : "security_operation_failed",
          message: configurationFailure ? "管理员鉴权尚未配置" : "双重验证操作失败，请稍后重试",
        },
      },
      { status: configurationFailure ? 503 : 500 },
    );
  }
}

export async function DELETE(request: Request) {
  const identity = await requireAdminIdentity(request);
  if (identity instanceof Response) return identity;
  try {
    await consumeAuthRateLimit(request, "admin_security", `${identity.id}:totp-cancel`, 20);
    const token = readRebindToken(request);
    let cancelled = false;
    if (token) {
      const deleted = await getDb()
        .delete(adminTotpRebindings)
        .where(
          and(
            eq(adminTotpRebindings.adminId, identity.id),
            eq(adminTotpRebindings.tokenHash, await hashOpaqueToken(token)),
          ),
        )
        .returning({ id: adminTotpRebindings.id });
      cancelled = deleted.length === 1;
    }
    if (cancelled) {
      await writeAudit({
        actor: identity.actor,
        action: "admin.totp.rebind_cancelled",
        targetType: "admin_account",
        targetId: identity.id,
        outcome: "allowed",
        risk: "high",
      });
    }
    const response = noStoreJson({ cancelled: true });
    response.headers.append("set-cookie", clearPrivateCookie(request, "totp_rebind"));
    return response;
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    return noStoreJson(
      { error: { code: "cancellation_failed", message: "暂时无法取消，请稍后重试" } },
      { status: 500 },
    );
  }
}

async function startRebinding(
  request: Request,
  identity: AdminIdentity,
  payload: Record<string, unknown>,
): Promise<Response> {
  await consumeAuthRateLimit(request, "admin_security", `${identity.id}:totp-start`, 8);
  const currentPassword = typeof payload.currentPassword === "string" ? payload.currentPassword : "";
  const currentCode = typeof payload.currentCode === "string" ? payload.currentCode.trim() : "";
  const challenge = await verifyAdminStepUp(identity, currentPassword, currentCode);
  if (!challenge) {
    await writeAudit({
      actor: identity.actor,
      action: "admin.totp.rebind_started",
      targetType: "admin_account",
      targetId: identity.id,
      outcome: "denied",
      risk: "critical",
      metadata: { reason: "invalid_step_up" },
    });
    return invalidCredentials();
  }

  const now = new Date();
  const nowIso = now.toISOString();
  const advanced = await getDb()
    .update(adminAccounts)
    .set({ totpLastCounter: challenge.acceptedCounter, updatedAt: nowIso })
    .where(
      and(
        eq(adminAccounts.id, identity.id),
        eq(adminAccounts.status, "active"),
        or(
          isNull(adminAccounts.totpLastCounter),
          lt(adminAccounts.totpLastCounter, challenge.acceptedCounter),
        ),
      ),
    )
    .returning({ id: adminAccounts.id, counter: adminAccounts.totpLastCounter });
  if (advanced.length !== 1 || advanced[0].counter !== challenge.acceptedCounter) {
    return noStoreJson(
      { error: { code: "security_conflict", message: "验证状态已变化，请重新输入验证码" } },
      { status: 409 },
    );
  }

  const id = crypto.randomUUID();
  const token = randomToken();
  const secret = createTotpSecret();
  const envelope = await encryptAuthSecret(secret, `admin-totp-rebind:${identity.id}:${id}`);
  const expiresAt = new Date(now.getTime() + REBIND_SECONDS * 1000).toISOString();
  const d1 = getD1();
  await d1.batch([
    d1.prepare("DELETE FROM admin_totp_rebindings WHERE admin_id = ?").bind(identity.id),
    d1.prepare(
      `INSERT INTO admin_totp_rebindings
        (id, admin_id, token_hash, secret_ciphertext, secret_nonce, expires_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).bind(
      id,
      identity.id,
      await hashOpaqueToken(token),
      envelope.ciphertext,
      envelope.nonce,
      expiresAt,
      nowIso,
    ),
  ]);

  await clearAuthRateLimit(request, "admin_security", `${identity.id}:totp-start`);
  await writeAudit({
    actor: identity.actor,
    action: "admin.totp.rebind_started",
    targetType: "admin_account",
    targetId: identity.id,
    outcome: "allowed",
    risk: "critical",
    metadata: { expiresInSeconds: REBIND_SECONDS },
  });
  const response = noStoreJson({
    username: identity.username,
    secret,
    uri: createTotpUri(identity.username, secret),
    expiresAt,
  });
  response.headers.append(
    "set-cookie",
    serializePrivateCookie(request, "totp_rebind", token, REBIND_SECONDS),
  );
  return response;
}

async function verifyRebinding(
  request: Request,
  identity: AdminIdentity,
  payload: Record<string, unknown>,
): Promise<Response> {
  await consumeAuthRateLimit(request, "admin_security", `${identity.id}:totp-verify`, 8);
  const code = typeof payload.code === "string" ? payload.code.trim() : "";
  const token = readRebindToken(request);
  if (!token) return expiredEnrollment(request);

  const tokenHash = await hashOpaqueToken(token);
  const [pending] = await getDb()
    .select()
    .from(adminTotpRebindings)
    .where(
      and(
        eq(adminTotpRebindings.adminId, identity.id),
        eq(adminTotpRebindings.tokenHash, tokenHash),
      ),
    )
    .limit(1);
  if (!pending || pending.expiresAt <= new Date().toISOString()) {
    if (pending) {
      await getDb().delete(adminTotpRebindings).where(eq(adminTotpRebindings.id, pending.id));
    }
    return expiredEnrollment(request);
  }

  const secret = await decryptAuthSecret(
    { ciphertext: pending.secretCiphertext, nonce: pending.secretNonce },
    `admin-totp-rebind:${identity.id}:${pending.id}`,
  );
  const acceptedCounter = await verifyTotp(secret, code, null);
  if (acceptedCounter === null) {
    await writeAudit({
      actor: identity.actor,
      action: "admin.totp.rebound",
      targetType: "admin_account",
      targetId: identity.id,
      outcome: "denied",
      risk: "critical",
      metadata: { reason: "invalid_new_totp" },
    });
    return noStoreJson(
      { error: { code: "invalid_code", message: "新验证器的验证码不正确" } },
      { status: 401 },
    );
  }

  const consumed = await getDb()
    .delete(adminTotpRebindings)
    .where(
      and(
        eq(adminTotpRebindings.id, pending.id),
        eq(adminTotpRebindings.tokenHash, tokenHash),
      ),
    )
    .returning({ id: adminTotpRebindings.id });
  if (consumed.length !== 1) {
    return noStoreJson(
      { error: { code: "security_conflict", message: "绑定状态已变化，请重新开始" } },
      { status: 409 },
    );
  }

  const permanentEnvelope = await encryptAuthSecret(secret, `admin-totp:${identity.id}`);
  const now = new Date().toISOString();
  const d1 = getD1();
  const [accountResult] = await d1.batch([
    d1.prepare(
      `UPDATE admin_accounts
       SET totp_secret_ciphertext = ?, totp_secret_nonce = ?,
           totp_last_counter = ?, updated_at = ?
       WHERE id = ? AND status = 'active'`,
    ).bind(
      permanentEnvelope.ciphertext,
      permanentEnvelope.nonce,
      acceptedCounter,
      now,
      identity.id,
    ),
    d1.prepare(
      "UPDATE admin_sessions SET revoked_at = ? WHERE admin_id = ? AND revoked_at IS NULL",
    ).bind(now, identity.id),
  ]);
  if ((accountResult.meta.changes ?? 0) !== 1) {
    return noStoreJson(
      { error: { code: "account_unavailable", message: "管理员账号当前不可用" } },
      { status: 409 },
    );
  }

  await clearAuthRateLimit(request, "admin_security", `${identity.id}:totp-verify`);
  await writeAudit({
    actor: identity.actor,
    action: "admin.totp.rebound",
    targetType: "admin_account",
    targetId: identity.id,
    outcome: "allowed",
    risk: "critical",
  });
  const response = noStoreJson({ reauthenticate: true });
  response.headers.append("set-cookie", clearPrivateCookie(request, "totp_rebind"));
  response.headers.append("set-cookie", clearPrivateCookie(request, "session"));
  return response;
}

function readRebindToken(request: Request): string | null {
  const token = readCookie(request.headers.get("cookie"), cookieNames("totp_rebind"));
  if (!token || token.length < 32 || token.length > 256) return null;
  return token;
}

function invalidCredentials(): Response {
  return noStoreJson(
    { error: { code: "invalid_credentials", message: "当前密码或验证码不正确，验证码不可重复使用" } },
    { status: 401 },
  );
}

function expiredEnrollment(request: Request): Response {
  const response = noStoreJson(
    { error: { code: "rebind_expired", message: "重新绑定会话已失效，请重新开始" } },
    { status: 401 },
  );
  response.headers.append("set-cookie", clearPrivateCookie(request, "totp_rebind"));
  return response;
}
