import {
  consumeAuthRateLimit,
  RateLimitError,
  rateLimitResponse,
} from "../../../../lib/admin-auth";
import { requireAdmin } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import { OpenAiCompatibleClient } from "../../../../lib/ai/openai-client";
import { loadProviderForOwner } from "../../../../lib/ai/provider";
import { validateProviderId } from "../../../../lib/ai/provider-validation";
import { noStoreJson, requireJsonRequest } from "../../../../lib/security/http";
import { assertAllowedFields } from "../../../../lib/security/validation";

export async function POST(request: Request) {
  const actor = await requireAdmin(request);
  if (actor instanceof Response) return actor;
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;
  let providerId: string | null = null;
  try {
    await consumeAuthRateLimit(request, "ai_provider_test", actor, 10);
    const payload: unknown = await request.json();
    assertAllowedFields(payload, ["providerId"]);
    providerId = validateProviderId(payload.providerId);
    const { provider, apiKey } = await loadProviderForOwner(providerId, actor);
    if (provider.kind === "anthropic_compatible") {
      throw new Error("Anthropic-compatible test adapter is not enabled yet");
    }
    const client = new OpenAiCompatibleClient({
      baseUrl: provider.baseUrl,
      apiKey,
      timeoutMs: 25_000,
    });
    await client.createResponse("Reply exactly: DAYLINK_OK", provider.textModel);
    await writeAudit({
      actor,
      action: "ai_provider.test",
      targetType: "ai_provider",
      targetId: providerId,
      outcome: "allowed",
      risk: "low",
      metadata: { connected: true },
    });
    return noStoreJson({ ok: true });
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    await writeAudit({
      actor,
      action: "ai_provider.test",
      targetType: "ai_provider",
      targetId: providerId,
      outcome: "failed",
      risk: "low",
    }).catch(() => undefined);
    return noStoreJson(
      {
        error: {
          code: "provider_test_failed",
          message: "AI 服务连接失败，请检查 Endpoint、模型和 API Key",
        },
      },
      { status: 502 },
    );
  }
}
