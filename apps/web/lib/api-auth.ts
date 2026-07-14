import { and, eq, isNull } from "drizzle-orm";
import { headers } from "next/headers";
import { getDb } from "../db";
import { mobileApiTokens } from "../db/schema";
import { getAdminIdentity } from "./admin-auth";
import type { AdminIdentity } from "./admin-auth";
import { sha256 } from "./security/encoding";
import { requireSameOriginMutation } from "./security/http";

export async function requireOperator(request: Request): Promise<string | Response> {
  const header = request.headers.get("authorization");
  if (header?.startsWith("Bearer ")) {
    const token = header.slice("Bearer ".length).trim();
    if (token.length >= 32 && token.length <= 256) {
      const now = new Date().toISOString();
      const [record] = await getDb()
        .select()
        .from(mobileApiTokens)
        .where(
          and(
            eq(mobileApiTokens.tokenHash, await sha256(token)),
            isNull(mobileApiTokens.revokedAt),
          ),
        )
        .limit(1);
      if (record && (!record.expiresAt || record.expiresAt > now)) {
        await getDb()
          .update(mobileApiTokens)
          .set({ lastUsedAt: now })
          .where(eq(mobileApiTokens.id, record.id));
        return record.ownerEmail;
      }
    }
  }

  const csrfFailure = requireSameOriginMutation(request);
  if (csrfFailure) return csrfFailure;
  const admin = await getAdminIdentity(
    request.headers.get("cookie"),
    request.headers.get("user-agent"),
  );
  if (admin) return admin.actor;
  return Response.json(
    { error: { code: "unauthorized", message: "Sign in or provide a valid API token" } },
    { status: 401, headers: { "cache-control": "no-store" } },
  );
}

export async function requireAdmin(request?: Request): Promise<string | Response> {
  const identity = await requireAdminIdentity(request);
  return identity instanceof Response ? identity : identity.actor;
}

export async function requireAdminIdentity(request?: Request): Promise<AdminIdentity | Response> {
  if (request) {
    const csrfFailure = requireSameOriginMutation(request);
    if (csrfFailure) return csrfFailure;
    const admin = await getAdminIdentity(
      request.headers.get("cookie"),
      request.headers.get("user-agent"),
    );
    if (admin) return admin;
  } else {
    const requestHeaders = await headers();
    const admin = await getAdminIdentity(
      requestHeaders.get("cookie"),
      requestHeaders.get("user-agent"),
    );
    if (admin) return admin;
  }
  return Response.json(
    { error: { code: "unauthorized", message: "Administrator sign-in is required" } },
    { status: 401, headers: { "cache-control": "no-store" } },
  );
}
