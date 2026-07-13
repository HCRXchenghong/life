import { and, desc, eq, isNull } from "drizzle-orm";
import { getDb } from "../../../../db";
import { mobileApiTokens } from "../../../../db/schema";
import { requireAdmin } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import { randomToken, sha256 } from "../../../../lib/security/encoding";
import {
  errorResponse,
  optionalText,
  requiredText,
} from "../../../../lib/security/validation";

function publicToken(record: typeof mobileApiTokens.$inferSelect) {
  return {
    id: record.id,
    name: record.name,
    tokenHint: record.tokenHint,
    expiresAt: record.expiresAt,
    lastUsedAt: record.lastUsedAt,
    revokedAt: record.revokedAt,
    createdAt: record.createdAt,
  };
}

export async function GET() {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  const tokens = await getDb()
    .select()
    .from(mobileApiTokens)
    .where(eq(mobileApiTokens.ownerEmail, actor))
    .orderBy(desc(mobileApiTokens.createdAt));
  return Response.json({ tokens: tokens.map(publicToken) });
}

export async function POST(request: Request) {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  try {
    const payload = (await request.json()) as Record<string, unknown>;
    const name = requiredText(payload.name, "name", 80);
    const expiresAt = optionalText(payload.expiresAt, "expiresAt", 64);
    if (expiresAt && (!Number.isFinite(Date.parse(expiresAt)) || expiresAt <= new Date().toISOString())) {
      throw new Error("expiresAt must be a future ISO timestamp");
    }
    const id = crypto.randomUUID();
    const plaintext = `dlk_${randomToken(36)}`;
    const now = new Date().toISOString();
    const [created] = await getDb()
      .insert(mobileApiTokens)
      .values({
        id,
        ownerEmail: actor,
        name,
        tokenHash: await sha256(plaintext),
        tokenHint: `dlk_••••${plaintext.slice(-6)}`,
        expiresAt,
        createdAt: now,
      })
      .returning();
    await writeAudit({
      actor,
      action: "mobile_token.create",
      targetType: "mobile_api_token",
      targetId: id,
      outcome: "allowed",
      risk: "high",
      metadata: { expiresAt },
    });
    return Response.json({ token: publicToken(created), plaintext }, { status: 201 });
  } catch (error) {
    return errorResponse(error);
  }
}

export async function DELETE(request: Request) {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  try {
    const id = requiredText(new URL(request.url).searchParams.get("id"), "id", 64);
    const now = new Date().toISOString();
    const changed = await getDb()
      .update(mobileApiTokens)
      .set({ revokedAt: now })
      .where(
        and(
          eq(mobileApiTokens.id, id),
          eq(mobileApiTokens.ownerEmail, actor),
          isNull(mobileApiTokens.revokedAt),
        ),
      )
      .returning({ id: mobileApiTokens.id });
    if (changed.length === 0) return errorResponse(new Error("Token not found"), 404);
    await writeAudit({
      actor,
      action: "mobile_token.revoke",
      targetType: "mobile_api_token",
      targetId: id,
      outcome: "allowed",
      risk: "high",
    });
    return Response.json({ revoked: true });
  } catch (error) {
    return errorResponse(error);
  }
}
