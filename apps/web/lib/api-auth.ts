import { and, eq, isNull } from "drizzle-orm";
import { getChatGPTUser } from "../app/chatgpt-auth";
import { getDb } from "../db";
import { mobileApiTokens } from "../db/schema";
import { sha256 } from "./security/encoding";

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

  const user = await getChatGPTUser();
  if (user) return user.email;
  return Response.json(
    { error: { code: "unauthorized", message: "Sign in or provide a valid API token" } },
    { status: 401 },
  );
}

export async function requireAdmin(): Promise<string | Response> {
  const user = await getChatGPTUser();
  if (user) return user.email;
  return Response.json(
    { error: { code: "unauthorized", message: "ChatGPT sign-in is required" } },
    { status: 401 },
  );
}
