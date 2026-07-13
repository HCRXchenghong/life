import { requireAdmin } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import { OpenAiCompatibleClient } from "../../../../lib/ai/openai-client";
import { loadProviderForOwner } from "../../../../lib/ai/provider";
import { errorResponse, requiredText } from "../../../../lib/security/validation";

export async function POST(request: Request) {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  let providerId: string | null = null;
  try {
    const payload = (await request.json()) as Record<string, unknown>;
    providerId = requiredText(payload.providerId, "providerId", 64);
    const { provider, apiKey } = await loadProviderForOwner(providerId, actor);
    if (provider.kind === "anthropic_compatible") {
      throw new Error("Anthropic-compatible test adapter is not enabled yet");
    }
    const client = new OpenAiCompatibleClient({ baseUrl: provider.baseUrl, apiKey });
    const result = await client.createResponse("Reply exactly: DAYLINK_OK", provider.textModel);
    await writeAudit({
      actor,
      action: "ai_provider.test",
      targetType: "ai_provider",
      targetId: providerId,
      outcome: "allowed",
      risk: "low",
      metadata: { responseId: result.id },
    });
    return Response.json({ ok: true, responseId: result.id, output: result.text.slice(0, 200) });
  } catch (error) {
    await writeAudit({
      actor,
      action: "ai_provider.test",
      targetType: "ai_provider",
      targetId: providerId,
      outcome: "failed",
      risk: "low",
    }).catch(() => undefined);
    return errorResponse(error, 502);
  }
}

