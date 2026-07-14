const FORBIDDEN_HOST_SUFFIXES = [
  ".internal",
  ".invalid",
  ".lan",
  ".local",
  ".localhost",
  ".test",
  ".home.arpa",
  ".localtest.me",
  ".lvh.me",
  ".nip.io",
  ".sslip.io",
];
const THIRD_PARTY_AI_PROTOCOLS = new Set(["openai_responses", "openai_compatible"]);

export type ThirdPartyAiProtocol = "openai_responses" | "openai_compatible";

export function parseHttpsBaseUrl(value: string): string {
  const url = new URL(value);
  const host = url.hostname.toLowerCase().replace(/\.$/, "");
  if (url.protocol !== "https:") throw new Error("AI Base URL must use HTTPS");
  if (url.username || url.password) throw new Error("AI Base URL must not contain credentials");
  if (url.search || url.hash) throw new Error("AI Base URL must not contain a query or fragment");
  if (
    host === "localhost" ||
    FORBIDDEN_HOST_SUFFIXES.some((suffix) => host === suffix.slice(1) || host.endsWith(suffix)) ||
    isForbiddenIpLiteral(host) ||
    (!host.includes(".") && !isIpv4Literal(host))
  ) {
    throw new Error("Private or loopback AI endpoints are not allowed by the hosted gateway");
  }
  url.hash = "";
  url.search = "";
  return url.toString().replace(/\/$/, "");
}

function isForbiddenIpLiteral(host: string): boolean {
  const unwrapped = host.startsWith("[") && host.endsWith("]") ? host.slice(1, -1) : host;
  if (unwrapped.includes(":")) return true;
  if (!isIpv4Literal(unwrapped)) return false;
  const [first, second] = unwrapped.split(".").map(Number);
  return (
    first === 0 ||
    first === 10 ||
    first === 127 ||
    (first === 100 && second >= 64 && second <= 127) ||
    (first === 169 && second === 254) ||
    (first === 172 && second >= 16 && second <= 31) ||
    (first === 192 && (second === 0 || second === 168)) ||
    (first === 198 && (second === 18 || second === 19 || second === 51)) ||
    (first === 203 && second === 0) ||
    first >= 224
  );
}

function isIpv4Literal(host: string): boolean {
  const parts = host.split(".");
  return parts.length === 4 && parts.every((part) => /^\d{1,3}$/.test(part) && Number(part) <= 255);
}

export function requiredText(value: unknown, field: string, max: number): string {
  if (typeof value !== "string") throw new Error(`${field} is required`);
  const normalized = value.trim();
  if (!normalized) throw new Error(`${field} is required`);
  if (normalized.length > max) throw new Error(`${field} is too long`);
  return normalized;
}

export function optionalText(value: unknown, field: string, max: number): string | null {
  if (value === undefined || value === null || value === "") return null;
  return requiredText(value, field, max);
}

export function optionalSecret(value: unknown, field: string, max: number): string | null {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string" || value.length > max || !value.trim()) {
    throw new Error(`${field} is invalid`);
  }
  if (/[\u0000-\u001f\u007f]/.test(value)) {
    throw new Error(`${field} contains unsupported characters`);
  }
  return value;
}

export function parseThirdPartyAiProtocol(value: unknown): ThirdPartyAiProtocol {
  const protocol = requiredText(value, "kind", 40);
  if (!THIRD_PARTY_AI_PROTOCOLS.has(protocol)) {
    throw new Error("Unsupported third-party AI protocol");
  }
  return protocol as ThirdPartyAiProtocol;
}

export function assertAllowedFields(
  value: unknown,
  allowedFields: readonly string[],
): asserts value is Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("JSON object required");
  }
  const allowed = new Set(allowedFields);
  const unknown = Object.keys(value).find((field) => !allowed.has(field));
  if (unknown) throw new Error(`Unexpected field: ${unknown}`);
}

export function isoInstant(value: unknown, field: string): string {
  const text = requiredText(value, field, 64);
  const date = new Date(text);
  if (!Number.isFinite(date.getTime())) throw new Error(`${field} must be an ISO-8601 instant`);
  return date.toISOString();
}

export function errorResponse(error: unknown, status = 400): Response {
  const message = error instanceof Error ? error.message : "Unexpected error";
  return Response.json({ error: { code: "invalid_request", message } }, { status });
}
