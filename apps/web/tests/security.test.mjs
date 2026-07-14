import assert from "node:assert/strict";
import test from "node:test";
import {
  cookieNames,
  readCookie,
  requireJsonRequest,
  requireSameOriginMutation,
  serializePrivateCookie,
} from "../lib/security/http.ts";
import { createTotpSecret, createTotpUri, verifyTotp } from "../lib/security/totp.ts";
import { authorizeBootstrapPolicy } from "../lib/security/bootstrap-policy.ts";
import {
  assertAllowedFields,
  optionalSecret,
  parseHttpsBaseUrl,
  parseThirdPartyAiProtocol,
} from "../lib/security/validation.ts";
import {
  canonicalAccountUsername,
  readBearerToken,
  validateAccountUsername,
  validateStrongPassword,
} from "../lib/security/account-credentials.ts";
import { sanitizeAuditMetadata } from "../lib/security/audit-metadata.ts";

test("TOTP matches the RFC 6238 SHA-1 vector and rejects replay", async () => {
  const secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ";
  const counter = await verifyTotp(secret, "287082", null, 59_000);
  assert.equal(counter, 1);
  assert.equal(await verifyTotp(secret, "287082", counter, 59_000), null);
});

test("TOTP enrollment values are Microsoft Authenticator compatible", () => {
  const secret = createTotpSecret();
  assert.match(secret, /^[A-Z2-7]{32}$/);
  const uri = createTotpUri("admin", secret);
  assert.match(uri, /^otpauth:\/\/totp\/Daylink%3Aadmin\?/);
  assert.match(uri, /issuer=Daylink/);
  assert.match(uri, /digits=6/);
  assert.match(uri, /period=30/);
});

test("cookie auth mutations require an exact same-origin browser request", () => {
  const accepted = new Request("https://daylink.example/api/auth/login", {
    method: "POST",
    headers: { origin: "https://daylink.example", "sec-fetch-site": "same-origin" },
  });
  assert.equal(requireSameOriginMutation(accepted), null);

  const crossSite = new Request("https://daylink.example/api/auth/login", {
    method: "POST",
    headers: { origin: "https://evil.example", "sec-fetch-site": "cross-site" },
  });
  assert.equal(requireSameOriginMutation(crossSite)?.status, 403);

  const missingOrigin = new Request("https://daylink.example/api/auth/login", { method: "POST" });
  assert.equal(requireSameOriginMutation(missingOrigin)?.status, 403);
});

test("private cookies are host-bound, HttpOnly, strict and readable by either runtime name", () => {
  const request = new Request("https://daylink.example/api/auth/login");
  const serialized = serializePrivateCookie(request, "session", "secret value", 300);
  assert.match(serialized, /^__Host-daylink_admin_session=/);
  assert.match(serialized, /HttpOnly/);
  assert.match(serialized, /SameSite=Strict/);
  assert.match(serialized, /Secure/);
  assert.match(serialized, /Path=\//);

  const value = readCookie(
    "theme=light; __Host-daylink_admin_session=secret%20value",
    cookieNames("session"),
  );
  assert.equal(value, "secret value");
});

test("production bootstrap requires both hosted identity and explicit allowlist", () => {
  const anonymous = authorizeBootstrapPolicy(new Headers(), "daylink.example", "owner@example.com");
  assert.deepEqual(anonymous, { allowed: false, reason: "identity_required" });

  const identityHeaders = new Headers({ "oai-authenticated-user-email": "Owner@Example.com" });
  assert.deepEqual(authorizeBootstrapPolicy(identityHeaders, "daylink.example", undefined), {
    allowed: false,
    reason: "allowlist_missing",
  });
  assert.deepEqual(authorizeBootstrapPolicy(identityHeaders, "daylink.example", "other@example.com"), {
    allowed: false,
    reason: "forbidden",
  });
  assert.deepEqual(authorizeBootstrapPolicy(identityHeaders, "daylink.example", "owner@example.com"), {
    allowed: true,
    actor: "bootstrap:allowlisted-user",
  });
});

test("localhost bootstrap remains available for local development", () => {
  assert.deepEqual(authorizeBootstrapPolicy(new Headers(), "127.0.0.1", undefined), {
    allowed: true,
    actor: "bootstrap:local",
  });
});

test("App account credentials are canonicalized and strongly validated", () => {
  assert.equal(validateAccountUsername(" Member.One ", "App 账号"), "Member.One");
  assert.equal(canonicalAccountUsername("Member.One"), "member.one");
  assert.equal(validateStrongPassword("Longer!Pass123"), "Longer!Pass123");
  assert.throws(() => validateAccountUsername("../admin", "App 账号"));
  assert.throws(() => validateStrongPassword("onlylowercase"));
  assert.throws(() => validateStrongPassword("NoSymbols1234"));
});

test("App bearer tokens reject malformed or ambiguous authorization values", () => {
  const token = `dlka_${"A".repeat(48)}`;
  assert.equal(readBearerToken(`Bearer ${token}`), token);
  assert.equal(readBearerToken(`bearer ${token}`), null);
  assert.equal(readBearerToken(`Bearer short`), null);
  assert.equal(readBearerToken(`Bearer ${token}.suffix`), null);
});

test("JSON mutation endpoints reject form and text payloads", () => {
  const json = new Request("https://daylink.example/api/app/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json; charset=utf-8" },
  });
  assert.equal(requireJsonRequest(json), null);
  const form = new Request("https://daylink.example/api/app/auth/login", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
  });
  assert.equal(requireJsonRequest(form)?.status, 415);
});

test("strict request schemas reject unrecognized credential fields", () => {
  const accepted = { username: "member", password: "secret" };
  assert.doesNotThrow(() => assertAllowedFields(accepted, ["username", "password"]));
  assert.throws(
    () => assertAllowedFields({ ...accepted, admin: true }, ["username", "password"]),
    /Unexpected field: admin/,
  );
  assert.throws(() => assertAllowedFields([accepted], ["username", "password"]));
});

test("AI endpoints accept only public HTTPS base URLs without embedded authority data", () => {
  assert.equal(parseHttpsBaseUrl("https://api.openai.com/v1/"), "https://api.openai.com/v1");
  for (const value of [
    "http://api.openai.com/v1",
    "https://user:pass@api.openai.com/v1",
    "https://api.openai.com/v1?token=secret",
    "https://127.0.0.1/v1",
    "https://2130706433/v1",
    "https://169.254.169.254/latest",
    "https://[::1]/v1",
    "https://metadata.google.internal/v1",
    "https://127.0.0.1.nip.io/v1",
  ]) {
    assert.throws(() => parseHttpsBaseUrl(value), value);
  }
});

test("AI API Key validation preserves exact bytes and rejects control characters", () => {
  const key = "  exact-key-with-spaces  ";
  assert.equal(optionalSecret(key, "apiKey", 4_096), key);
  assert.equal(optionalSecret("", "apiKey", 4_096), null);
  assert.throws(() => optionalSecret("secret\nheader", "apiKey", 4_096));
  assert.throws(() => optionalSecret("   ", "apiKey", 4_096));
});

test("third-party AI configuration accepts only Responses-compatible protocols", () => {
  assert.equal(parseThirdPartyAiProtocol("openai_compatible"), "openai_compatible");
  assert.equal(parseThirdPartyAiProtocol("openai_responses"), "openai_responses");
  assert.throws(() => parseThirdPartyAiProtocol("anthropic_compatible"));
  assert.throws(() => parseThirdPartyAiProtocol("codex_login"));
});

test("audit metadata removes secret-bearing fields and bounds untrusted values", () => {
  const sanitized = sanitizeAuditMetadata({
    providerId: "provider-1",
    toolCount: 3,
    apiKey: "must-not-survive",
    authorization: "Bearer must-not-survive",
    nested: {
      password: "must-not-survive",
      reason: "invalid\ncredentials",
    },
    longValue: "x".repeat(500),
  });
  assert.deepEqual(sanitized, {
    providerId: "provider-1",
    toolCount: 3,
    nested: { reason: "invalidcredentials" },
    longValue: "x".repeat(256),
  });
  const circular = { safe: true };
  circular.self = circular;
  assert.doesNotThrow(() => JSON.stringify(sanitizeAuditMetadata({ circular })));
});
