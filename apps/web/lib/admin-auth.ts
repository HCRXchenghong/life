import { and, eq, isNull } from "drizzle-orm";
import { getD1, getDb } from "../db";
import { adminAccounts, adminSessions, authRateLimits } from "../db/schema";
import {
  hashOpaqueToken,
  hashPrivateIdentifier,
  randomToken,
} from "./security/auth-crypto";
import { clientAddress, cookieNames, readCookie } from "./security/http";

const SESSION_SECONDS = 12 * 60 * 60;
const RATE_WINDOW_MS = 15 * 60 * 1000;
const RATE_BLOCK_MS = 30 * 60 * 1000;

export type AdminIdentity = {
  id: string;
  username: string;
  actor: string;
};

export type BootstrapState =
  | { kind: "uninitialized" }
  | { kind: "pending"; enrollmentAuthorized: boolean }
  | { kind: "active" };

export class RateLimitError extends Error {
  readonly retryAfterSeconds: number;

  constructor(retryAfterSeconds: number) {
    super("Too many attempts. Try again later.");
    this.retryAfterSeconds = retryAfterSeconds;
  }
}

export async function getBootstrapState(cookieHeader: string | null): Promise<BootstrapState> {
  const db = getDb();
  const [account] = await db.select().from(adminAccounts).limit(1);
  if (!account) return { kind: "uninitialized" };
  if (account.status === "active" || account.status === "disabled") return { kind: "active" };

  const now = new Date().toISOString();
  if (!account.enrollmentExpiresAt || account.enrollmentExpiresAt <= now) {
    await db.delete(adminAccounts).where(eq(adminAccounts.id, account.id));
    return { kind: "uninitialized" };
  }

  const token = readCookie(cookieHeader, cookieNames("enrollment"));
  const enrollmentAuthorized = Boolean(
    token &&
      account.enrollmentTokenHash &&
      (await hashOpaqueToken(token)) === account.enrollmentTokenHash,
  );
  return { kind: "pending", enrollmentAuthorized };
}

export async function getPendingEnrollment(cookieHeader: string | null) {
  const token = readCookie(cookieHeader, cookieNames("enrollment"));
  if (!token) return null;
  const tokenHash = await hashOpaqueToken(token);
  const now = new Date().toISOString();
  const [account] = await getDb()
    .select()
    .from(adminAccounts)
    .where(
      and(
        eq(adminAccounts.status, "pending"),
        eq(adminAccounts.enrollmentTokenHash, tokenHash),
      ),
    )
    .limit(1);
  if (!account || !account.enrollmentExpiresAt || account.enrollmentExpiresAt <= now) return null;
  return account;
}

export async function getAdminIdentity(
  cookieHeader: string | null,
  userAgent: string | null,
): Promise<AdminIdentity | null> {
  const token = readCookie(cookieHeader, cookieNames("session"));
  if (!token || token.length < 32 || token.length > 256) return null;
  const tokenHash = await hashOpaqueToken(token);
  const now = new Date().toISOString();
  const db = getDb();
  const [session] = await db
    .select()
    .from(adminSessions)
    .where(
      and(
        eq(adminSessions.tokenHash, tokenHash),
        isNull(adminSessions.revokedAt),
      ),
    )
    .limit(1);
  if (!session || session.expiresAt <= now) return null;

  if (session.userAgentHash) {
    const presentedHash = await hashPrivateIdentifier("user-agent", userAgent ?? "");
    if (presentedHash !== session.userAgentHash) {
      await db
        .update(adminSessions)
        .set({ revokedAt: now })
        .where(eq(adminSessions.id, session.id));
      return null;
    }
  }

  const [account] = await db
    .select()
    .from(adminAccounts)
    .where(and(eq(adminAccounts.id, session.adminId), eq(adminAccounts.status, "active")))
    .limit(1);
  if (!account) return null;

  if (Date.now() - new Date(session.lastSeenAt).getTime() > 5 * 60 * 1000) {
    await db
      .update(adminSessions)
      .set({ lastSeenAt: now })
      .where(eq(adminSessions.id, session.id));
  }

  return { id: account.id, username: account.username, actor: `admin:${account.id}` };
}

export async function createAdminSession(
  adminId: string,
  userAgent: string | null,
): Promise<{ token: string; maxAgeSeconds: number }> {
  const token = randomToken();
  const now = new Date();
  const expiresAt = new Date(now.getTime() + SESSION_SECONDS * 1000).toISOString();
  await getDb().insert(adminSessions).values({
    id: crypto.randomUUID(),
    adminId,
    tokenHash: await hashOpaqueToken(token),
    userAgentHash: await hashPrivateIdentifier("user-agent", userAgent ?? ""),
    expiresAt,
    lastSeenAt: now.toISOString(),
  });
  return { token, maxAgeSeconds: SESSION_SECONDS };
}

export async function revokeAdminSession(cookieHeader: string | null): Promise<void> {
  const token = readCookie(cookieHeader, cookieNames("session"));
  if (!token) return;
  await getDb()
    .update(adminSessions)
    .set({ revokedAt: new Date().toISOString() })
    .where(eq(adminSessions.tokenHash, await hashOpaqueToken(token)));
}

export async function consumeAuthRateLimit(
  request: Request,
  action: "setup" | "login" | "totp_enrollment",
  identity: string,
  maximumAttempts: number,
): Promise<void> {
  const now = Date.now();
  const nowIso = new Date(now).toISOString();
  const cutoffIso = new Date(now - RATE_WINDOW_MS).toISOString();
  const blockUntilIso = new Date(now + RATE_BLOCK_MS).toISOString();
  const key = await hashPrivateIdentifier(
    `rate-limit:${action}`,
    `${clientAddress(request)}\0${identity.toLowerCase()}`,
  );
  const record = await getD1()
    .prepare(
      `INSERT INTO auth_rate_limits
        (bucket_key, action, window_started_at, attempts, blocked_until, updated_at)
       VALUES (?, ?, ?, 1, NULL, ?)
       ON CONFLICT(bucket_key) DO UPDATE SET
         action = excluded.action,
         attempts = CASE
           WHEN auth_rate_limits.window_started_at <= ? THEN 1
           ELSE auth_rate_limits.attempts + 1
         END,
         window_started_at = CASE
           WHEN auth_rate_limits.window_started_at <= ? THEN excluded.window_started_at
           ELSE auth_rate_limits.window_started_at
         END,
         blocked_until = CASE
           WHEN auth_rate_limits.blocked_until > excluded.updated_at
             THEN auth_rate_limits.blocked_until
           WHEN auth_rate_limits.window_started_at <= ? THEN NULL
           WHEN auth_rate_limits.attempts + 1 > ? THEN ?
           ELSE NULL
         END,
         updated_at = excluded.updated_at
       RETURNING attempts, blocked_until`,
    )
    .bind(
      key,
      action,
      nowIso,
      nowIso,
      cutoffIso,
      cutoffIso,
      cutoffIso,
      maximumAttempts,
      blockUntilIso,
    )
    .first<{ attempts: number; blocked_until: string | null }>();
  if (record?.blocked_until && record.blocked_until > nowIso) {
    throw new RateLimitError(
      Math.max(1, Math.ceil((new Date(record.blocked_until).getTime() - now) / 1000)),
    );
  }
}

export async function clearAuthRateLimit(
  request: Request,
  action: "setup" | "login" | "totp_enrollment",
  identity: string,
): Promise<void> {
  const key = await hashPrivateIdentifier(
    `rate-limit:${action}`,
    `${clientAddress(request)}\0${identity.toLowerCase()}`,
  );
  await getDb().delete(authRateLimits).where(eq(authRateLimits.bucketKey, key));
}

export function rateLimitResponse(error: RateLimitError): Response {
  return Response.json(
    { error: { code: "rate_limited", message: "尝试次数过多，请稍后再试" } },
    {
      status: 429,
      headers: {
        "cache-control": "no-store",
        "retry-after": String(error.retryAfterSeconds),
      },
    },
  );
}
