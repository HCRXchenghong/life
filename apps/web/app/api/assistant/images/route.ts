import { requireOperator } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import { OpenAiCompatibleClient } from "../../../../lib/ai/openai-client";
import { loadProviderForGateway } from "../../../../lib/ai/provider";
import { bytesToBase64 } from "../../../../lib/security/encoding";
import { errorResponse, requiredText } from "../../../../lib/security/validation";

const SIZES = new Set(["1024x1024", "1536x1024", "1024x1536"]);
const QUALITIES = new Set(["low", "medium", "high"]);

export async function POST(request: Request) {
  const actor = await requireOperator(request);
  if (actor instanceof Response) return actor;
  let providerId: string | null = null;
  try {
    const payload = (await request.json()) as Record<string, unknown>;
    providerId = requiredText(payload.providerId, "providerId", 64);
    const prompt = requiredText(payload.prompt, "prompt", 4_000);
    const size = requiredText(payload.size ?? "1024x1024", "size", 20);
    const quality = requiredText(payload.quality ?? "medium", "quality", 20);
    if (!SIZES.has(size)) throw new Error("Unsupported image size");
    if (!QUALITIES.has(quality)) throw new Error("Unsupported image quality");
    const { provider, apiKey } = await loadProviderForGateway(providerId, actor);
    if (!provider.imageModel) throw new Error("Image model is not configured");
    const client = new OpenAiCompatibleClient({ baseUrl: provider.baseUrl, apiKey });
    const image = await client.generateImage({
      prompt,
      model: provider.imageModel,
      size,
      quality: quality as "low" | "medium" | "high",
    });
    await writeAudit({
      actor,
      action: "ai_gateway.image",
      targetType: "ai_provider",
      targetId: provider.id,
      outcome: "allowed",
      risk: "medium",
      metadata: { size, quality, bytes: image.bytes.byteLength },
    });
    return Response.json({
      created: Math.floor(Date.now() / 1_000),
      data: [
        {
          b64_json: bytesToBase64(image.bytes),
          revised_prompt: image.revisedPrompt,
        },
      ],
    });
  } catch (error) {
    await writeAudit({
      actor,
      action: "ai_gateway.image",
      targetType: "ai_provider",
      targetId: providerId,
      outcome: "failed",
      risk: "medium",
    }).catch(() => undefined);
    return errorResponse(error, 502);
  }
}
