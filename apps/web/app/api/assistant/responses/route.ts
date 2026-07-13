import { eq } from "drizzle-orm";
import { getDb } from "../../../../db";
import { aiRuns } from "../../../../db/schema";
import { requireOperator } from "../../../../lib/api-auth";
import { writeAudit } from "../../../../lib/audit";
import { gatewayResponseRequest } from "../../../../lib/ai/gateway-validation";
import { OpenAiCompatibleClient } from "../../../../lib/ai/openai-client";
import { loadProviderForGateway } from "../../../../lib/ai/provider";
import { sha256 } from "../../../../lib/security/encoding";
import { errorResponse } from "../../../../lib/security/validation";

export async function POST(request: Request) {
  const actor = await requireOperator(request);
  if (actor instanceof Response) return actor;
  const runId = crypto.randomUUID();
  let providerId: string | null = null;
  try {
    const contentLength = Number(request.headers.get("content-length") ?? 0);
    if (contentLength > 256_000) throw new Error("Request body exceeds 256 KB");
    const raw = (await request.json()) as Record<string, unknown>;
    const input = gatewayResponseRequest(raw);
    providerId = input.providerId;
    const { provider, apiKey } = await loadProviderForGateway(input.providerId, actor);
    if (provider.kind === "anthropic_compatible") {
      throw new Error("Anthropic-compatible Responses adapter is not enabled");
    }
    const now = new Date().toISOString();
    await getDb().insert(aiRuns).values({
      id: runId,
      ownerEmail: provider.ownerEmail,
      providerConfigId: provider.id,
      kind: "assistant",
      status: "running",
      model: provider.textModel,
      requestDigest: await sha256(JSON.stringify({ input: input.input, tools: input.tools })),
      startedAt: now,
      createdAt: now,
      updatedAt: now,
    });
    const client = new OpenAiCompatibleClient({ baseUrl: provider.baseUrl, apiKey });
    const result = await client.createToolResponse({
      model: provider.textModel,
      input: input.input,
      tools: input.tools,
      store: true,
      parallel_tool_calls: false,
      max_output_tokens: 4_096,
      ...(input.previousResponseId
        ? { previous_response_id: input.previousResponseId }
        : {}),
    });
    const completedAt = new Date().toISOString();
    await getDb()
      .update(aiRuns)
      .set({
        status: "succeeded",
        responseId: typeof result.id === "string" ? result.id : null,
        completedAt,
        updatedAt: completedAt,
      })
      .where(eq(aiRuns.id, runId));
    await writeAudit({
      actor,
      action: "ai_gateway.response",
      targetType: "ai_provider",
      targetId: provider.id,
      outcome: "allowed",
      risk: "medium",
      metadata: { runId, toolCount: input.tools.length },
    });
    return Response.json(result);
  } catch (error) {
    const completedAt = new Date().toISOString();
    await getDb()
      .update(aiRuns)
      .set({
        status: "failed",
        errorCode: "gateway_error",
        errorMessage: error instanceof Error ? error.message.slice(0, 1_000) : "Unknown error",
        completedAt,
        updatedAt: completedAt,
      })
      .where(eq(aiRuns.id, runId))
      .catch(() => undefined);
    await writeAudit({
      actor,
      action: "ai_gateway.response",
      targetType: "ai_provider",
      targetId: providerId,
      outcome: "failed",
      risk: "medium",
    }).catch(() => undefined);
    return errorResponse(error, 502);
  }
}
