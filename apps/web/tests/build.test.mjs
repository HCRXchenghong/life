import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("builds a standalone React administration application", async () => {
  const html = await readFile(new URL("../dist/index.html", import.meta.url), "utf8");
  assert.match(html, /<title>Daylink 管理后台<\/title>/);
  assert.match(html, /\/assets\/index-/);
  assert.doesNotMatch(html, /_next|vinext/i);
});

test("uses the app-owned administrator bootstrap API", async () => {
  const [app, auth] = await Promise.all([
    readFile(new URL("../src/App.tsx", import.meta.url), "utf8"),
    readFile(new URL("../src/Auth.tsx", import.meta.url), "utf8"),
  ]);
  assert.match(app, /\/api\/admin\/bootstrap/);
  assert.match(auth, /\/api\/auth\/login/);
  assert.match(auth, /Microsoft Authenticator/);
});
