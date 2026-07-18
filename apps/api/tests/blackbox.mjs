import { createHmac, randomUUID } from "node:crypto";

const baseURL = process.env.DAYLINK_TEST_BASE_URL ?? "http://127.0.0.1:18080";
const publicOrigin = process.env.DAYLINK_TEST_PUBLIC_ORIGIN ?? "http://localhost:18080";
const setupToken = process.env.DAYLINK_TEST_SETUP_TOKEN ?? "";
const userAgent = "daylink-blackbox/1";

function invariant(value, message) {
  if (!value) throw new Error(message);
}

async function request(path, { method = "GET", body, cookie, bearer, sameOrigin = false } = {}) {
  const headers = { "user-agent": userAgent };
  if (body !== undefined) headers["content-type"] = "application/json";
  if (cookie) headers.cookie = cookie;
  if (bearer) headers.authorization = `Bearer ${bearer}`;
  if (sameOrigin) headers.origin = publicOrigin;
  const response = await fetch(`${baseURL}${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    redirect: "manual",
  });
  const contentType = response.headers.get("content-type") ?? "";
  const payload = contentType.includes("application/json") ? await response.json() : null;
  return { response, payload };
}

function responseCookie(response, expectedName) {
  const values = response.headers.getSetCookie();
  const match = values.find((value) => value.startsWith(`${expectedName}=`));
  invariant(match, `missing ${expectedName} cookie`);
  return match.split(";", 1)[0];
}

function decodeBase32(value) {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  for (const character of value.replace(/=+$/g, "").toUpperCase()) {
    const index = alphabet.indexOf(character);
    invariant(index >= 0, "invalid base32 secret");
    bits += index.toString(2).padStart(5, "0");
  }
  const bytes = [];
  for (let offset = 0; offset + 8 <= bits.length; offset += 8) {
    bytes.push(Number.parseInt(bits.slice(offset, offset + 8), 2));
  }
  return Buffer.from(bytes);
}

function totp(secret, now = Date.now()) {
  const counter = BigInt(Math.floor(now / 30_000));
  const message = Buffer.alloc(8);
  message.writeBigUInt64BE(counter);
  const digest = createHmac("sha1", decodeBase32(secret)).update(message).digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const value = (digest.readUInt32BE(offset) & 0x7fffffff) % 1_000_000;
  return value.toString().padStart(6, "0");
}

async function main() {
  let result = await request("/api/health");
  invariant(result.response.status === 200 && result.payload?.service === "daylink-api", "health failed");
  invariant(result.response.headers.get("x-content-type-options") === "nosniff", "API security headers missing");

  const html = await fetch(`${baseURL}/admin`).then((response) => response.text());
  invariant(html.includes('id="root"') && !html.includes("把服务器和生活安排"), "standalone React admin not served");

  result = await request("/api/admin/bootstrap");
  invariant(result.response.status === 200 && result.payload?.state === "uninitialized", "bootstrap state invalid");

  const administratorPassword = "Admin!Pass12345";
  if (setupToken) {
    result = await request("/api/auth/setup", {
      method: "POST",
      sameOrigin: true,
      body: { username: "daylink-admin", password: administratorPassword, confirmPassword: administratorPassword, setupToken: "incorrect-bootstrap-token" },
    });
    invariant(result.response.status === 403, "invalid deployment setup token accepted");
  }
  result = await request("/api/auth/setup", {
    method: "POST",
    sameOrigin: true,
    body: { username: "daylink-admin", password: administratorPassword, confirmPassword: administratorPassword, setupToken },
  });
  invariant(result.response.status === 201, "administrator setup failed");
  const enrollmentCookie = responseCookie(result.response, "daylink_admin_enrollment");

  result = await request("/api/auth/setup/enrollment", { cookie: enrollmentCookie });
  invariant(result.response.status === 200 && result.payload?.secret && result.payload?.uri?.startsWith("otpauth://"), "TOTP enrollment missing");
  const currentCode = totp(result.payload.secret);

  result = await request("/api/auth/setup/verify", {
    method: "POST",
    cookie: enrollmentCookie,
    sameOrigin: true,
    body: { code: currentCode },
  });
  invariant(result.response.status === 200, "TOTP enrollment verification failed");
  const adminCookie = responseCookie(result.response, "daylink_admin_session");

  result = await request("/api/admin/bootstrap", { cookie: adminCookie });
  invariant(result.payload?.state === "authenticated", "administrator session unavailable");

  result = await request("/api/admin/app-accounts", {
    method: "POST",
    cookie: adminCookie,
    body: { username: "missing-origin", password: "Missing!Origin123", confirmPassword: "Missing!Origin123" },
  });
  invariant(result.response.status === 403, "administrator CSRF guard failed");

  result = await request("/api/admin/providers", {
    method: "POST",
    cookie: adminCookie,
    sameOrigin: true,
    body: {
      name: "blocked-localhost",
      kind: "openai_compatible",
      baseUrl: "https://localhost/v1",
      textModel: "test",
      apiKey: "not-a-real-key",
      enabled: true,
    },
  });
  invariant(result.response.status === 400, "private AI endpoint accepted");

  const accountAPassword = "AccountA!Pass123";
  const accountBPassword = "AccountB!Pass123";
  for (const [username, password] of [["member-a", accountAPassword], ["member-b", accountBPassword]]) {
    result = await request("/api/admin/app-accounts", {
      method: "POST",
      cookie: adminCookie,
      sameOrigin: true,
      body: { username, password, confirmPassword: password },
    });
    invariant(result.response.status === 201, `creating ${username} failed`);
  }

  async function appLogin(username, password, deviceName = "blackbox") {
    const login = await request("/api/app/auth/login", {
      method: "POST",
      body: { username, password, deviceName },
    });
    invariant(login.response.status === 200 && login.payload?.tokens?.accessToken && login.payload?.tokens?.refreshToken, `login ${username} failed`);
    return login.payload.tokens;
  }

  const tokensA = await appLogin("member-a", accountAPassword);
  const tokensASecondary = await appLogin("member-a", accountAPassword, "blackbox-secondary");
  const tokensATarget = await appLogin("member-a", accountAPassword, "blackbox-target");
  const tokensB = await appLogin("member-b", accountBPassword);
  result = await request("/api/app/auth/devices", { bearer: tokensA.accessToken });
  invariant(
    result.response.status === 200 &&
      result.payload?.devices?.length === 3 &&
      result.payload.devices.filter((device) => device.current).length === 1 &&
      result.payload.devices.every((device) => typeof device.trusted === "boolean") &&
      result.payload.devices.every((device) => device.name.startsWith("blackbox")),
    "account-scoped device list failed",
  );
  const currentDeviceId = result.payload.devices.find((device) => device.current)?.id;
  const targetDeviceId = result.payload.devices.find((device) => device.name === "blackbox-target")?.id;
  invariant(currentDeviceId && targetDeviceId, "device IDs missing");
  result = await request(`/api/app/auth/devices/${targetDeviceId}`, {
    method: "DELETE",
    bearer: tokensB.accessToken,
  });
  invariant(result.response.status === 404, "cross-account device revocation disclosed or revoked a device");
  result = await request(`/api/app/auth/devices/${currentDeviceId}`, {
    method: "DELETE",
    bearer: tokensA.accessToken,
  });
  invariant(result.response.status === 400, "current device could revoke itself through targeted revocation");
  result = await request(`/api/app/auth/devices/${targetDeviceId}`, {
    method: "DELETE",
    bearer: tokensA.accessToken,
  });
  invariant(result.response.status === 200 && result.payload?.revoked === true, "targeted device revocation failed");
  result = await request("/api/app/auth/session", { bearer: tokensATarget.accessToken });
  invariant(result.response.status === 401, "targeted device remained authenticated");
  result = await request("/api/app/auth/session", { bearer: tokensASecondary.accessToken });
  invariant(result.response.status === 200, "targeted revocation affected another device");
  result = await request("/api/app/auth/devices", {
    method: "DELETE",
    bearer: tokensA.accessToken,
  });
  invariant(result.response.status === 200 && result.payload?.revoked === 1, "revoking other devices failed");
  result = await request("/api/app/auth/session", { bearer: tokensASecondary.accessToken });
  invariant(result.response.status === 401, "revoked secondary device remained authenticated");
  result = await request("/api/app/auth/session", { bearer: tokensA.accessToken });
  invariant(result.response.status === 200, "current device was revoked with other devices");
  const objectId = randomUUID();
  const operationId = randomUUID();
  const deviceId = randomUUID();
  const mutation = {
    operationId,
    deviceId,
    expectedRevision: 0,
    revision: 1,
    ciphertext: Buffer.from("opaque-client-ciphertext").toString("base64"),
    nonce: Buffer.alloc(12, 7).toString("base64"),
    keyVersion: 1,
    clientUpdatedAt: new Date().toISOString(),
  };
  result = await request(`/api/sync/objects/schedules/${objectId}`, {
    method: "PUT",
    bearer: tokensA.accessToken,
    body: mutation,
  });
  invariant(result.response.status === 200 && result.payload?.revision === 1, "encrypted sync write failed");
  const firstCursor = result.payload.cursor;

  result = await request(`/api/sync/objects/schedules/${objectId}`, {
    method: "PUT",
    bearer: tokensA.accessToken,
    body: mutation,
  });
  invariant(result.response.status === 200 && result.payload?.idempotent === true && result.payload?.cursor === firstCursor, "sync idempotency failed");

  result = await request("/api/sync/changes?cursor=0", { bearer: tokensA.accessToken });
  invariant(result.response.status === 200 && result.payload?.changes?.length === 1, "account A sync pull failed");
  invariant(result.payload.changes[0].ciphertext === mutation.ciphertext, "sync ciphertext changed");
  result = await request("/api/sync/changes?cursor=0", { bearer: tokensB.accessToken });
  invariant(result.response.status === 200 && result.payload?.changes?.length === 0, "cross-account sync isolation failed");
  result = await request("/api/sync/changes?cursor=0", { cookie: adminCookie });
  invariant(result.response.status === 401, "administrator gained content sync access");

  const startsAt = new Date(Date.now() + 86_400_000);
  const endsAt = new Date(startsAt.getTime() + 3_600_000);
  result = await request("/api/polls", {
    method: "POST",
    bearer: tokensA.accessToken,
    body: {
      title: "Blackbox poll",
      description: "",
      timezone: "Asia/Shanghai",
      slots: [
        { label: "A", startsAt: startsAt.toISOString(), endsAt: endsAt.toISOString() },
        { label: "B", startsAt: new Date(startsAt.getTime() + 86_400_000).toISOString(), endsAt: new Date(endsAt.getTime() + 86_400_000).toISOString() },
      ],
    },
  });
  invariant(result.response.status === 201 && result.payload?.poll?.publicToken, "poll creation failed");
  const publicToken = result.payload.poll.publicToken;
  result = await request(`/api/polls/${encodeURIComponent(publicToken)}`);
  invariant(result.response.status === 200 && result.payload?.slots?.length === 2, "public poll unavailable");
  const votes = result.payload.slots.map((slot) => ({ slotId: slot.id, response: "yes" }));
  result = await request(`/api/polls/${encodeURIComponent(publicToken)}/votes`, {
    method: "POST",
    body: { displayName: "Blackbox", votes },
  });
  invariant(result.response.status === 201 && result.payload?.editToken, "public poll vote failed");
  result = await request("/api/polls", { bearer: tokensA.accessToken });
  const managedPoll = result.payload?.polls?.find((poll) => poll.title === "Blackbox poll");
  invariant(
    result.response.status === 200 && managedPoll?.candidateCount === 2 && managedPoll?.participantCount === 1,
    "managed poll list counts failed",
  );
  result = await request("/api/polls", { bearer: tokensB.accessToken });
  invariant(
    result.response.status === 200 && !result.payload?.polls?.some((poll) => poll.title === "Blackbox poll"),
    "managed poll list crossed account boundary",
  );

  result = await request("/api/app/auth/refresh", { method: "POST", body: { refreshToken: tokensA.refreshToken } });
  invariant(result.response.status === 200 && result.payload?.tokens?.accessToken, "refresh rotation failed");
  const rotatedA = result.payload.tokens;
  result = await request("/api/app/auth/devices", { bearer: rotatedA.accessToken });
  invariant(
    result.response.status === 200 && result.payload?.devices?.find((device) => device.current)?.id === currentDeviceId,
    "refresh rotation changed the stable device ID",
  );
  result = await request("/api/app/auth/refresh", { method: "POST", body: { refreshToken: tokensA.refreshToken } });
  invariant(result.response.status === 401, "refresh token replay accepted");
  result = await request("/api/app/auth/session", { bearer: tokensA.accessToken });
  invariant(result.response.status === 401, "old access token survived refresh rotation");
  result = await request("/api/app/auth/session", { bearer: rotatedA.accessToken });
  invariant(result.response.status === 200, "rotated access token rejected");

  result = await request("/api/auth/logout", { method: "POST", cookie: adminCookie, sameOrigin: true });
  invariant(result.response.status === 200, "administrator logout failed");
  result = await request("/api/auth/login", {
    method: "POST",
    sameOrigin: true,
    body: { username: "daylink-admin", password: administratorPassword, code: currentCode },
  });
  invariant(result.response.status === 401, "TOTP replay accepted");

  process.stdout.write("Daylink black-box integration passed\n");
}

main().catch((error) => {
  process.stderr.write(`Daylink black-box integration failed: ${error.message}\n`);
  process.exitCode = 1;
});
