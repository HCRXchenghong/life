import { and, desc, eq } from "drizzle-orm";
import { getDb } from "../../../../db";
import { aiProviderConfigs } from "../../../../db/schema";
import {
  consumeAuthRateLimit,
  RateLimitError,
  rateLimitResponse,
} from "../../../../lib/admin-auth";
import { requireAdmin } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import { publicProvider } from "../../../../lib/ai/provider";
import { validateProviderMutation } from "../../../../lib/ai/provider-validation";
import { encryptSecret, secretHint } from "../../../../lib/security/secrets";
import { noStoreJson, requireJsonRequest } from "../../../../lib/security/http";

export async function GET() {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  const providers = await getDb()
    .select()
    .from(aiProviderConfigs)
    .where(eq(aiProviderConfigs.ownerEmail, actor))
    .orderBy(desc(aiProviderConfigs.updatedAt));
  return noStoreJson({ providers: providers.map(publicProvider) });
}

export async function POST(request: Request) {
  const actor = await requireAdmin(request);
  if (actor instanceof Response) return actor;
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;
  try {
    await consumeAuthRateLimit(request, "ai_provider_admin", actor, 30);
    const input = validateProviderMutation(await request.json());
    const { id, name, kind, baseUrl, textModel, imageModel, apiKey, enabled } = input;
    const now = new Date().toISOString();
    const db = getDb();

    if (id) {
      const [existing] = await db
        .select()
        .from(aiProviderConfigs)
        .where(and(eq(aiProviderConfigs.id, id), eq(aiProviderConfigs.ownerEmail, actor)))
        .limit(1);
      if (!existing) {
        return noStoreJson(
          { error: { code: "not_found", message: "AI 服务不存在" } },
          { status: 404 },
        );
      }
      const encrypted = apiKey ? await encryptSecret(apiKey, actor) : null;
      try {
        await db
          .update(aiProviderConfigs)
          .set({
            name,
            kind,
            baseUrl,
            textModel,
            imageModel,
            enabled,
            updatedAt: now,
            ...(encrypted && apiKey
              ? {
                  apiKeyCiphertext: encrypted.ciphertext,
                  apiKeyNonce: encrypted.nonce,
                  apiKeyHint: secretHint(apiKey),
                }
              : {}),
          })
          .where(and(eq(aiProviderConfigs.id, id), eq(aiProviderConfigs.ownerEmail, actor)));
      } catch {
        const [conflict] = await db
          .select({ id: aiProviderConfigs.id })
          .from(aiProviderConfigs)
          .where(and(eq(aiProviderConfigs.ownerEmail, actor), eq(aiProviderConfigs.name, name)))
          .limit(1);
        if (conflict && conflict.id !== id) return providerNameConflict();
        throw new Error("AI 服务暂时无法保存");
      }
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
        .where(and(eq(aiProviderConfigs.id, id), eq(aiProviderConfigs.ownerEmail, actor)));
      return noStoreJson({ provider: publicProvider(updated) });
    }

    if (!apiKey) throw new Error("apiKey is required for a new provider");
    const encrypted = await encryptSecret(apiKey, actor);
    const providerId = crypto.randomUUID();
    let created: typeof aiProviderConfigs.$inferSelect;
    try {
      [created] = await db
        .insert(aiProviderConfigs)
        .values({
          id: providerId,
          ownerEmail: actor,
          name,
          kind,
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
    } catch {
      const [conflict] = await db
        .select({ id: aiProviderConfigs.id })
        .from(aiProviderConfigs)
        .where(and(eq(aiProviderConfigs.ownerEmail, actor), eq(aiProviderConfigs.name, name)))
        .limit(1);
      if (conflict) return providerNameConflict();
      throw new Error("AI 服务暂时无法保存");
    }
    await writeAudit({
      actor,
      action: "ai_provider.create",
      targetType: "ai_provider",
      targetId: providerId,
      outcome: "allowed",
      risk: "high",
      metadata: { kind },
    });
    return noStoreJson({ provider: publicProvider(created) }, { status: 201 });
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    const message = error instanceof Error ? error.message : "请求无效";
    const unavailable = message.includes("AI_SECRET_MASTER_KEY") || message.includes("not configured");
    return noStoreJson(
      {
        error: {
          code: unavailable ? "ai_secret_storage_unavailable" : "invalid_request",
          message: unavailable ? "AI 密钥存储尚未配置" : message,
        },
      },
      { status: unavailable ? 503 : 400 },
    );
  }
}

function providerNameConflict(): Response {
  return noStoreJson(
    { error: { code: "provider_name_unavailable", message: "同名 AI 服务已存在" } },
    { status: 409 },
  );
}
