const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

export function readCookie(cookieHeader: string | null, names: string[]): string | null {
  if (!cookieHeader) return null;
  const wanted = new Set(names);
  for (const part of cookieHeader.split(";")) {
    const separator = part.indexOf("=");
    if (separator < 0) continue;
    const name = part.slice(0, separator).trim();
    if (!wanted.has(name)) continue;
    try {
      return decodeURIComponent(part.slice(separator + 1).trim());
    } catch {
      return null;
    }
  }
  return null;
}

export function secureCookieName(request: Request, purpose: "session" | "enrollment"): string {
  const secure = new URL(request.url).protocol === "https:";
  const base = `daylink_admin_${purpose}`;
  return secure ? `__Host-${base}` : base;
}

export function cookieNames(purpose: "session" | "enrollment"): string[] {
  const base = `daylink_admin_${purpose}`;
  return [`__Host-${base}`, base];
}

export function serializePrivateCookie(
  request: Request,
  purpose: "session" | "enrollment",
  value: string,
  maxAgeSeconds: number,
): string {
  const secure = new URL(request.url).protocol === "https:";
  return [
    `${secureCookieName(request, purpose)}=${encodeURIComponent(value)}`,
    "Path=/",
    "HttpOnly",
    "SameSite=Strict",
    secure ? "Secure" : "",
    `Max-Age=${Math.max(0, Math.floor(maxAgeSeconds))}`,
  ]
    .filter(Boolean)
    .join("; ");
}

export function clearPrivateCookie(
  request: Request,
  purpose: "session" | "enrollment",
): string {
  return serializePrivateCookie(request, purpose, "", 0);
}

export function requireSameOriginMutation(request: Request): Response | null {
  if (SAFE_METHODS.has(request.method.toUpperCase())) return null;
  const origin = request.headers.get("origin");
  const fetchSite = request.headers.get("sec-fetch-site");
  if (!origin || origin !== new URL(request.url).origin) {
    return Response.json(
      { error: { code: "forbidden", message: "Same-origin request required" } },
      { status: 403, headers: { "cache-control": "no-store" } },
    );
  }
  if (fetchSite && fetchSite !== "same-origin") {
    return Response.json(
      { error: { code: "forbidden", message: "Cross-site request rejected" } },
      { status: 403, headers: { "cache-control": "no-store" } },
    );
  }
  return null;
}

export function requireJsonRequest(request: Request): Response | null {
  const contentType = request.headers.get("content-type")?.split(";", 1)[0]?.trim().toLowerCase();
  if (contentType === "application/json") return null;
  return Response.json(
    { error: { code: "unsupported_media_type", message: "JSON request required" } },
    { status: 415, headers: { "cache-control": "no-store" } },
  );
}

export function noStoreJson(body: unknown, init: ResponseInit = {}): Response {
  const headers = new Headers(init.headers);
  headers.set("cache-control", "no-store, max-age=0");
  headers.set("pragma", "no-cache");
  return Response.json(body, { ...init, headers });
}

export function clientAddress(request: Request): string {
  return (
    request.headers.get("cf-connecting-ip") ??
    request.headers.get("x-real-ip") ??
    request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ??
    "unknown"
  );
}
