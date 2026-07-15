import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);

test("builds a standalone React administration application", async () => {
  const html = await readFile(new URL("../dist/index.html", import.meta.url), "utf8");
  assert.match(html, /<title>Daylink 管理后台<\/title>/);
  assert.match(html, /\/assets\/index-/);
  assert.doesNotMatch(html, /_next|vinext|chatgpt\.site|signin-with-chatgpt/i);
});

test("uses the app-owned administrator bootstrap API", async () => {
  const [app, auth] = await Promise.all([
    readFile(new URL("../src/App.tsx", import.meta.url), "utf8"),
    readFile(new URL("../src/Auth.tsx", import.meta.url), "utf8"),
  ]);
  assert.match(app, /\/api\/admin\/bootstrap/);
  assert.match(auth, /\/api\/auth\/login/);
  assert.match(auth, /Microsoft Authenticator/);
  assert.doesNotMatch(app + auth, /signin-with-chatgpt|oai-authenticated/i);
});

test("contains no Sites hosting manifest", async () => {
  await assert.rejects(access(new URL("../.openai/hosting.json", root)));
});
