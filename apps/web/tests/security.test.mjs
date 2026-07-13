import assert from "node:assert/strict";
import test from "node:test";
import {
  cookieNames,
  readCookie,
  requireSameOriginMutation,
  serializePrivateCookie,
} from "../lib/security/http.ts";
import { createTotpSecret, createTotpUri, verifyTotp } from "../lib/security/totp.ts";
import { authorizeBootstrapPolicy } from "../lib/security/bootstrap-policy.ts";

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
