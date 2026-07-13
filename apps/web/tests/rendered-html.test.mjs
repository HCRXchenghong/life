import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const origin = "http://127.0.0.1:4173";
let server;
let serverOutput = "";

async function request(path = "/") {
  return fetch(`${origin}${path}`, { headers: { accept: "text/html" } });
}

test.before(async () => {
  server = spawn("npm", ["run", "dev", "--", "--port", "4173"], {
    cwd: new URL("../", import.meta.url),
    env: process.env,
    stdio: ["ignore", "pipe", "pipe"],
  });
  server.stdout.on("data", (chunk) => { serverOutput += chunk; });
  server.stderr.on("data", (chunk) => { serverOutput += chunk; });

  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) {
      throw new Error(`production server exited early:\n${serverOutput}`);
    }
    try {
      const response = await fetch(`${origin}/api/health`);
      if (response.ok) return;
    } catch {
      // The socket is expected to reject until the Worker runtime is ready.
    }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error(`production server did not become ready:\n${serverOutput}`);
});

test.after(() => {
  server?.kill("SIGTERM");
});

test("server-renders the Daylink product home", async () => {
  const response = await request();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);
  const html = await response.text();
  assert.match(html, /<title>Daylink · SSH 与日程协作<\/title>/i);
  assert.match(html, /把服务器和生活安排/);
  assert.match(html, /SSH Core/);
  assert.match(html, /AI Tools/);
  assert.match(html, /Time Poll/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape|react-loading-skeleton/);
});

test("exposes a small health endpoint", async () => {
  const response = await request("/api/health");
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.equal(payload.status, "ok");
  assert.equal(payload.service, "daylink-web");
});

test("removes all disposable starter artifacts", async () => {
  const [page, layout, packageJson] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
  ]);
  assert.doesNotMatch(page, /SkeletonPreview|codex-preview/);
  assert.doesNotMatch(layout, /Starter Project|codex-preview/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  await assert.rejects(access(new URL("../app/_sites-preview/SkeletonPreview.tsx", root)));
});
