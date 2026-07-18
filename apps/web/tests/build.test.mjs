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

test("renders real server metrics and paginated Chinese audit controls", async () => {
  const dashboard = await readFile(new URL("../src/Dashboard.tsx", import.meta.url), "utf8");
  assert.match(dashboard, /\/api\/admin\/overview/);
  assert.match(dashboard, /CPU/);
  assert.match(dashboard, /运行内存/);
  assert.match(dashboard, /磁盘存储/);
  assert.match(dashboard, /page=\$\{page\}&pageSize=20/);
  assert.match(dashboard, /format=csv/);
  assert.match(dashboard, /下载日志/);
});

test("configures AI plans with monthly token quotas only", async () => {
  const dashboard = await readFile(new URL("../src/Dashboard.tsx", import.meta.url), "utf8");
  assert.match(dashboard, /plusMonthly/);
  assert.match(dashboard, /自然月/);
  assert.doesNotMatch(dashboard, /weeklyTokens|plusWeekly|proWeekly|周额度/);
});

test("keeps each friend poll link private and supports multiple time blocks", async () => {
  const [app, selection] = await Promise.all([
    readFile(new URL("../src/App.tsx", import.meta.url), "utf8"),
    readFile(new URL("../src/FriendSelectionPage.tsx", import.meta.url), "utf8"),
  ]);
  assert.match(app, /\/select\//);
  assert.match(selection, /\/api\/poll-invites\//);
  assert.match(selection, /可单选，也可多选/);
  assert.match(selection, /mergeBlocks/);
  assert.doesNotMatch(selection, /participants|其他朋友/);
});
