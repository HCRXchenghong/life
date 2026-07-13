import { env } from "cloudflare:workers";
import { desc, eq } from "drizzle-orm";
import { getDb } from "../../../../db";
import { aiRuns, generatedAssets } from "../../../../db/schema";
import { requireAdmin } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import { OpenAiCompatibleClient } from "../../../../lib/ai/openai-client";
import { loadProviderForOwner } from "../../../../lib/ai/provider";
import { sha256 } from "../../../../lib/security/encoding";
import {
  errorResponse,
  requiredText,
} from "../../../../lib/security/validation";

type ImageEnv = { GENERATED_ASSETS: R2Bucket };
const QUALITY = new Set(["low", "medium", "high"]);

export async function GET() {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  const assets = await getDb()
    .select({
      id: generatedAssets.id,
      providerConfigId: generatedAssets.providerConfigId,
      contentType: generatedAssets.contentType,
      byteSize: generatedAssets.byteSize,
      width: generatedAssets.width,
      height: generatedAssets.height,
      createdAt: generatedAssets.createdAt,
    })
    .from(generatedAssets)
    .where(eq(generatedAssets.ownerEmail, actor))
    .orderBy(desc(generatedAssets.createdAt))
    .limit(50);
  return Response.json({
    assets: assets.map((asset) => ({ ...asset, url: `/api/admin/images/${asset.id}` })),
  });
}

export async function POST(request: Request) {
  const actor = await requireAdmin(request);
  if (actor instanceof Response) return actor;
  const runId = crypto.randomUUID();
  let providerId = "";
  try {
    const payload = (await request.json()) as Record<string, unknown>;
    providerId = requiredText(payload.providerId, "providerId", 64);
    const prompt = requiredText(payload.prompt, "prompt", 8000);
    const size = normalizeSize(payload.size);
    const quality = normalizeQuality(payload.quality);
    const { provider, apiKey } = await loadProviderForOwner(providerId, actor);
    if (!provider.imageModel) throw new Error("This provider has no image model configured");
    if (provider.kind === "anthropic_compatible") {
      throw new Error("This provider does not support the OpenAI Images API");
    }

    const promptDigest = await sha256(prompt);
    const now = new Date().toISOString();
    const db = getDb();
    await db.insert(aiRuns).values({
      id: runId,
      ownerEmail: actor,
      providerConfigId: providerId,
      kind: "image",
      status: "running",
      model: provider.imageModel,
      requestDigest: promptDigest,
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    });

    const client = new OpenAiCompatibleClient({ baseUrl: provider.baseUrl, apiKey });
    const result = await client.generateImage({
      prompt,
      model: provider.imageModel,
      size,
      quality,
    });
    const assetId = crypto.randomUUID();
    const r2Key = `${actor.replaceAll(/[^a-zA-Z0-9_.-]/g, "_")}/${assetId}.png`;
    await (env as unknown as ImageEnv).GENERATED_ASSETS.put(r2Key, result.bytes, {
      httpMetadata: { contentType: result.contentType },
      customMetadata: { ownerDigest: await sha256(actor), promptDigest },
    });
    const [width, height] = size === "auto" ? [null, null] : size.split("x").map(Number);
    await db.batch([
      db.insert(generatedAssets).values({
        id: assetId,
        ownerEmail: actor,
        providerConfigId: providerId,
        aiRunId: runId,
        r2Key,
        promptDigest,
        contentType: result.contentType,
        byteSize: result.bytes.byteLength,
        width,
        height,
        createdAt: now,
      }),
      db
        .update(aiRuns)
        .set({ status: "succeeded", completedAt: now, updatedAt: now })
        .where(eq(aiRuns.id, runId)),
    ]);
    await writeAudit({
      actor,
      action: "image.generate",
      targetType: "generated_asset",
      targetId: assetId,
      outcome: "allowed",
      risk: "medium",
      metadata: { providerId, model: provider.imageModel, size, quality },
    });
    return Response.json(
      {
        asset: {
          id: assetId,
          url: `/api/admin/images/${assetId}`,
          contentType: result.contentType,
          byteSize: result.bytes.byteLength,
          revisedPrompt: result.revisedPrompt,
        },
      },
      { status: 201 },
    );
  } catch (error) {
    const now = new Date().toISOString();
    await getDb()
      .update(aiRuns)
      .set({
        status: "failed",
        errorCode: "image_generation_failed",
        errorMessage: error instanceof Error ? error.message.slice(0, 500) : "Unknown error",
        completedAt: now,
        updatedAt: now,
      })
      .where(eq(aiRuns.id, runId))
      .catch(() => undefined);
    await writeAudit({
      actor,
      action: "image.generate",
      targetType: "ai_provider",
      targetId: providerId || null,
      outcome: "failed",
      risk: "medium",
    }).catch(() => undefined);
    return errorResponse(error, 502);
  }
}

function normalizeQuality(value: unknown): "low" | "medium" | "high" {
  const quality = value ?? "medium";
  if (typeof quality !== "string" || !QUALITY.has(quality)) throw new Error("Invalid quality");
  return quality as "low" | "medium" | "high";
}

function normalizeSize(value: unknown): string {
  if (value === undefined || value === null || value === "") return "1024x1024";
  if (value === "auto") return "auto";
  if (typeof value !== "string" || !/^\d{2,4}x\d{2,4}$/.test(value)) {
    throw new Error("Invalid image size");
  }
  const [width, height] = value.split("x").map(Number);
  if (width > 3840 || height > 3840 || width % 16 || height % 16) {
    throw new Error("Image dimensions must be multiples of 16 and no greater than 3840");
  }
  return value;
}
