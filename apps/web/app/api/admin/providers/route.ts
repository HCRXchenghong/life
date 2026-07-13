import { and, desc, eq } from "drizzle-orm";
import { getDb } from "../../../../db";
import { aiProviderConfigs } from "../../../../db/schema";
import { requireAdmin } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import { publicProvider } from "../../../../lib/ai/provider";
import { encryptSecret, secretHint } from "../../../../lib/security/secrets";
import {
  errorResponse,
  optionalText,
  parseHttpsBaseUrl,
  requiredText,
} from "../../../../lib/security/validation";

const PROVIDER_KINDS = new Set([
  "openai_responses",
  "openai_compatible",
  "anthropic_compatible",
]);

export async function GET() {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  const providers = await getDb()
    .select()
    .from(aiProviderConfigs)
    .where(eq(aiProviderConfigs.ownerEmail, actor))
    .orderBy(desc(aiProviderConfigs.updatedAt));
  return Response.json({ providers: providers.map(publicProvider) });
}

export async function POST(request: Request) {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  try {
    const payload = (await request.json()) as Record<string, unknown>;
    const id = optionalText(payload.id, "id", 64);
    const name = requiredText(payload.name, "name", 80);
    const kind = requiredText(payload.kind, "kind", 40);
    if (!PROVIDER_KINDS.has(kind)) throw new Error("Unsupported AI provider kind");
    const baseUrl = parseHttpsBaseUrl(requiredText(payload.baseUrl, "baseUrl", 400));
    const textModel = requiredText(payload.textModel, "textModel", 120);
    const imageModel = optionalText(payload.imageModel, "imageModel", 120);
    const apiKey = optionalText(payload.apiKey, "apiKey", 4096);
    const enabled = payload.enabled !== false;
    const now = new Date().toISOString();
    const db = getDb();

    if (id) {
      const [existing] = await db
        .select()
        .from(aiProviderConfigs)
        .where(and(eq(aiProviderConfigs.id, id), eq(aiProviderConfigs.ownerEmail, actor)))
        .limit(1);
      if (!existing) return errorResponse(new Error("Provider not found"), 404);
      const encrypted = apiKey ? await encryptSecret(apiKey, actor) : null;
      await db
        .update(aiProviderConfigs)
        .set({
          name,
          kind: kind as typeof existing.kind,
          baseUrl,
          textModel,
          imageModel,
          enabled,
          updatedAt: now,
          ...(encrypted
            ? {
                apiKeyCiphertext: encrypted.ciphertext,
                apiKeyNonce: encrypted.nonce,
                apiKeyHint: secretHint(apiKey!),
              }
            : {}),
        })
        .where(and(eq(aiProviderConfigs.id, id), eq(aiProviderConfigs.ownerEmail, actor)));
      await writeAudit({
        actor,
        action: "ai_provider.update",
        targetType: "ai_provider",
        targetId: id,
        outcome: "allowed",
        risk: "high",
        metadata: { kind, keyRotated: Boolean(apiKey) },
      });
      const [updated] = await db
        .select()
        .from(aiProviderConfigs)
        .where(eq(aiProviderConfigs.id, id));
      return Response.json({ provider: publicProvider(updated) });
    }

    if (!apiKey) throw new Error("apiKey is required for a new provider");
    const encrypted = await encryptSecret(apiKey, actor);
    const providerId = crypto.randomUUID();
    const [created] = await db
      .insert(aiProviderConfigs)
      .values({
        id: providerId,
        ownerEmail: actor,
        name,
        kind: kind as "openai_responses" | "openai_compatible" | "anthropic_compatible",
        baseUrl,
        textModel,
        imageModel,
        apiKeyCiphertext: encrypted.ciphertext,
        apiKeyNonce: encrypted.nonce,
        apiKeyHint: secretHint(apiKey),
        enabled,
        createdAt: now,
        updatedAt: now,
      })
      .returning();
    await writeAudit({
      actor,
      action: "ai_provider.create",
      targetType: "ai_provider",
      targetId: providerId,
      outcome: "allowed",
      risk: "high",
      metadata: { kind },
    });
    return Response.json({ provider: publicProvider(created) }, { status: 201 });
  } catch (error) {
    return errorResponse(error);
  }
}

