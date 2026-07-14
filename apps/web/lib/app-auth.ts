import { and, eq, isNull } from "drizzle-orm";
import { getDb } from "../db";
import { appAccounts, appSessions } from "../db/schema";
import { hashOpaqueToken, randomToken } from "./security/auth-crypto";
import { readBearerToken } from "./security/account-credentials";
import { noStoreJson } from "./security/http";

const ACCESS_SECONDS = 15 * 60;
const REFRESH_SECONDS = 30 * 24 * 60 * 60;

export type AppIdentity = {
  accountId: string;
  username: string;
  sessionId: string;
  deviceName: string;
  passwordChangeRequired: boolean;
};

export type AppTokenPair = {
  accessToken: string;
  accessExpiresAt: string;
  refreshToken: string;
  refreshExpiresAt: string;
};

export async function createAppSession(
  accountId: string,
  deviceName: string,
): Promise<AppTokenPair> {
  const sessionId = crypto.randomUUID();
  const pair = await newTokenPair();
  const now = new Date().toISOString();
  await getDb().insert(appSessions).values({
    id: sessionId,
    accountId,
    accessTokenHash: await hashOpaqueToken(pair.accessToken),
    refreshTokenHash: await hashOpaqueToken(pair.refreshToken),
    deviceName,
    accessExpiresAt: pair.accessExpiresAt,
    refreshExpiresAt: pair.refreshExpiresAt,
    lastSeenAt: now,
    createdAt: now,
  });
  return pair;
}

export async function rotateAppSession(
  refreshToken: string,
): Promise<{ pair: AppTokenPair; accountId: string } | null> {
  if (!readBearerToken(`Bearer ${refreshToken}`)) return null;
  const refreshTokenHash = await hashOpaqueToken(refreshToken);
  const now = new Date().toISOString();
  const [session] = await getDb()
    .select()
    .from(appSessions)
    .where(and(eq(appSessions.refreshTokenHash, refreshTokenHash), isNull(appSessions.revokedAt)))
    .limit(1);
  if (!session || session.refreshExpiresAt <= now) return null;

  const [account] = await getDb()
    .select({ id: appAccounts.id, status: appAccounts.status })
    .from(appAccounts)
    .where(eq(appAccounts.id, session.accountId))
    .limit(1);
  if (!account || account.status !== "active") return null;

  const pair = await newTokenPair();
  const changed = await getDb()
    .update(appSessions)
    .set({
      accessTokenHash: await hashOpaqueToken(pair.accessToken),
      refreshTokenHash: await hashOpaqueToken(pair.refreshToken),
      accessExpiresAt: pair.accessExpiresAt,
      refreshExpiresAt: pair.refreshExpiresAt,
      lastSeenAt: now,
    })
    .where(
      and(
        eq(appSessions.id, session.id),
        eq(appSessions.refreshTokenHash, refreshTokenHash),
        isNull(appSessions.revokedAt),
      ),
    )
    .returning({ id: appSessions.id });
  if (changed.length !== 1) return null;
  return { pair, accountId: account.id };
}

export async function requireAppIdentity(request: Request): Promise<AppIdentity | Response> {
  const token = readBearerToken(request.headers.get("authorization"));
  if (!token) return appUnauthorized();
  const now = new Date().toISOString();
  const [record] = await getDb()
    .select({
      accountId: appAccounts.id,
      username: appAccounts.username,
      status: appAccounts.status,
      passwordChangeRequired: appAccounts.passwordChangeRequired,
      sessionId: appSessions.id,
      deviceName: appSessions.deviceName,
      accessExpiresAt: appSessions.accessExpiresAt,
      lastSeenAt: appSessions.lastSeenAt,
    })
    .from(appSessions)
    .innerJoin(appAccounts, eq(appSessions.accountId, appAccounts.id))
    .where(
      and(
        eq(appSessions.accessTokenHash, await hashOpaqueToken(token)),
        isNull(appSessions.revokedAt),
      ),
    )
    .limit(1);
  if (!record || record.status !== "active" || record.accessExpiresAt <= now) {
    return appUnauthorized();
  }

  if (Date.now() - new Date(record.lastSeenAt).getTime() > 5 * 60 * 1000) {
    await getDb()
      .update(appSessions)
      .set({ lastSeenAt: now })
      .where(eq(appSessions.id, record.sessionId));
  }
  return {
    accountId: record.accountId,
    username: record.username,
    sessionId: record.sessionId,
    deviceName: record.deviceName,
    passwordChangeRequired: record.passwordChangeRequired,
  };
}

export async function revokeAppSession(sessionId: string): Promise<void> {
  await getDb()
    .update(appSessions)
    .set({ revokedAt: new Date().toISOString() })
    .where(and(eq(appSessions.id, sessionId), isNull(appSessions.revokedAt)));
}

async function newTokenPair(): Promise<AppTokenPair> {
  const now = Date.now();
  return {
    accessToken: `dlka_${randomToken(36)}`,
    accessExpiresAt: new Date(now + ACCESS_SECONDS * 1000).toISOString(),
    refreshToken: `dlkr_${randomToken(48)}`,
    refreshExpiresAt: new Date(now + REFRESH_SECONDS * 1000).toISOString(),
  };
}

function appUnauthorized(): Response {
  return noStoreJson(
    { error: { code: "unauthorized", message: "App authentication is required" } },
    { status: 401 },
  );
}
