const PRIVATE_IPV4 = [
  /^10\./,
  /^127\./,
  /^169\.254\./,
  /^192\.168\./,
  /^172\.(1[6-9]|2\d|3[01])\./,
];

export function parseHttpsBaseUrl(value: string): string {
  const url = new URL(value);
  const host = url.hostname.toLowerCase();
  if (url.protocol !== "https:") throw new Error("AI Base URL must use HTTPS");
  if (
    host === "localhost" ||
    host === "::1" ||
    host.endsWith(".local") ||
    PRIVATE_IPV4.some((pattern) => pattern.test(host))
  ) {
    throw new Error("Private or loopback AI endpoints are not allowed by the hosted gateway");
  }
  url.hash = "";
  url.search = "";
  return url.toString().replace(/\/$/, "");
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

