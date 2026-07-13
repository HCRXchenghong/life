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
};

type ImageOptions = {
  prompt: string;
  model: string;
  size: string;
  quality: "low" | "medium" | "high";
};

export class OpenAiCompatibleClient {
  constructor(private readonly config: OpenAiClientConfig) {}

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
    const response = await fetch(`${this.config.baseUrl}${path}`, {
      method: "POST",
      headers: {
        authorization: `Bearer ${this.config.apiKey}`,
        "content-type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(120_000),
    });
    const requestId = response.headers.get("x-request-id");
    const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      const detail = asRecord(payload.error);
      const message = typeof detail.message === "string" ? detail.message : "AI provider request failed";
      const code = typeof detail.code === "string" ? detail.code : "provider_error";
      throw new AiGatewayError(message, response.status, code, requestId);
    }
    return payload;
  }
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
