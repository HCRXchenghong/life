const AUTHENTICATED_EMAIL_HEADER = "oai-authenticated-user-email";

export type BootstrapAuthorization =
  | { allowed: true; actor: string }
  | { allowed: false; reason: "identity_required" | "allowlist_missing" | "forbidden" };

export function authorizeBootstrapPolicy(
  requestHeaders: Headers,
  hostname: string,
  configuredEmails: string | undefined,
): BootstrapAuthorization {
  if (isLoopback(hostname)) return { allowed: true, actor: "bootstrap:local" };

  const email = requestHeaders.get(AUTHENTICATED_EMAIL_HEADER)?.trim().toLowerCase();
  if (!email) return { allowed: false, reason: "identity_required" };

  const allowedEmails = new Set(
    (configuredEmails ?? "")
      .split(",")
      .map((value) => value.trim().toLowerCase())
      .filter(Boolean),
  );
  if (allowedEmails.size === 0) return { allowed: false, reason: "allowlist_missing" };
  if (!allowedEmails.has(email)) return { allowed: false, reason: "forbidden" };
  return { allowed: true, actor: "bootstrap:allowlisted-user" };
}

export function requestHostname(requestHeaders: Headers): string {
  const forwardedHost = requestHeaders.get("x-forwarded-host")?.split(",")[0]?.trim();
  const host = forwardedHost || requestHeaders.get("host") || "";
  if (host.startsWith("[")) return host.slice(1, host.indexOf("]"));
  return host.split(":")[0].toLowerCase();
}

function isLoopback(hostname: string): boolean {
  const normalized = hostname.toLowerCase();
  return normalized === "localhost" || normalized === "127.0.0.1" || normalized === "::1";
}
