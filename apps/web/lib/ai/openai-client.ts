import { parseHttpsBaseUrl } from "../security/validation";

export class AiGatewayError extends Error {
  constructor(
    message: string,
    readonly status: number,
    readonly code: string,
    readonly requestId: string | null,
  ) {
    super(message);
  }
}

type OpenAiClientConfig = {
  baseUrl: string;
  apiKey: string;
  timeoutMs?: number;
};

type ImageOptions = {
  prompt: string;
  model: string;
  size: string;
  quality: "low" | "medium" | "high";
};

export class OpenAiCompatibleClient {
  private readonly config: Required<OpenAiClientConfig>;

  constructor(config: OpenAiClientConfig) {
    this.config = {
      baseUrl: parseHttpsBaseUrl(config.baseUrl),
      apiKey: config.apiKey,
      timeoutMs: config.timeoutMs ?? 120_000,
    };
  }

  async createResponse(input: string, model: string): Promise<{ id: string; text: string }> {
    const payload = await this.postJson("/responses", {
      model,
      input,
      store: false,
      max_output_tokens: 64,
    });
    return {
      id: typeof payload.id === "string" ? payload.id : "",
      text: extractOutputText(payload),
    };
  }

  async createToolResponse(body: Record<string, unknown>): Promise<Record<string, unknown>> {
    return this.postJson("/responses", body);
  }

  async generateImage(options: ImageOptions): Promise<{
    bytes: Uint8Array;
    contentType: string;
    revisedPrompt: string | null;
  }> {
    const payload = await this.postJson("/images/generations", {
      model: options.model,
      prompt: options.prompt,
      n: 1,
      size: options.size,
      quality: options.quality,
      output_format: "png",
    });
    const first = Array.isArray(payload.data) ? payload.data[0] : null;
    if (!first || typeof first !== "object") throw new Error("Image provider returned no image");
    const record = first as Record<string, unknown>;
    if (typeof record.b64_json !== "string") {
      throw new Error("Image provider did not return base64 image data");
    }
    return {
      bytes: decodeBase64(record.b64_json),
      contentType: "image/png",
      revisedPrompt: typeof record.revised_prompt === "string" ? record.revised_prompt : null,
    };
  }

  private async postJson(path: string, body: Record<string, unknown>): Promise<Record<string, unknown>> {
    let response: Response;
    try {
      response = await fetch(`${this.config.baseUrl}${path}`, {
        method: "POST",
        headers: {
          authorization: `Bearer ${this.config.apiKey}`,
          "content-type": "application/json",
        },
        body: JSON.stringify(body),
        cache: "no-store",
        credentials: "omit",
        redirect: "error",
        signal: AbortSignal.timeout(this.config.timeoutMs),
      });
    } catch {
      throw new AiGatewayError("AI provider is unreachable", 502, "provider_unreachable", null);
    }
    const requestId = safeIdentifier(response.headers.get("x-request-id"));
    const payload = await readJsonResponse(response, 32 * 1024 * 1024);
    if (!response.ok) {
      throw new AiGatewayError("AI provider request failed", response.status, "provider_error", requestId);
    }
    return payload;
  }
}

async function readJsonResponse(response: Response, maximumBytes: number): Promise<Record<string, unknown>> {
  const declaredLength = Number(response.headers.get("content-length") ?? 0);
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    await response.body?.cancel().catch(() => undefined);
    throw new AiGatewayError("AI provider response is too large", 502, "provider_response_too_large", null);
  }
  if (!response.body) return {};
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    length += value.byteLength;
    if (length > maximumBytes) {
      await reader.cancel().catch(() => undefined);
      throw new AiGatewayError("AI provider response is too large", 502, "provider_response_too_large", null);
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return asRecord(JSON.parse(new TextDecoder().decode(bytes)));
  } catch {
    throw new AiGatewayError("AI provider returned invalid JSON", 502, "provider_invalid_response", null);
  }
}

function safeIdentifier(value: string | null): string | null {
  if (!value) return null;
  return /^[A-Za-z0-9._:-]{1,128}$/.test(value) ? value : null;
}

function extractOutputText(payload: Record<string, unknown>): string {
  if (typeof payload.output_text === "string") return payload.output_text;
  if (!Array.isArray(payload.output)) return "";
  const chunks: string[] = [];
  for (const item of payload.output) {
    const record = asRecord(item);
    if (!Array.isArray(record.content)) continue;
    for (const content of record.content) {
      const contentRecord = asRecord(content);
      if (typeof contentRecord.text === "string") chunks.push(contentRecord.text);
    }
  }
  return chunks.join("\n");
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === "object" ? (value as Record<string, unknown>) : {};
}

function decodeBase64(value: string): Uint8Array {
  const binary = atob(value);
  return Uint8Array.from(binary, (char) => char.charCodeAt(0));
}
