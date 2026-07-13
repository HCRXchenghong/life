import {
  consumeAuthRateLimit,
  getPendingEnrollment,
  RateLimitError,
  rateLimitResponse,
} from "../../../../../lib/admin-auth";
import {
  createTotpUri,
  decryptAuthSecret,
} from "../../../../../lib/security/auth-crypto";
import { noStoreJson } from "../../../../../lib/security/http";

export async function GET(request: Request) {
  const fetchSite = request.headers.get("sec-fetch-site");
  if (fetchSite && fetchSite !== "same-origin" && fetchSite !== "none") {
    return noStoreJson(
      { error: { code: "forbidden", message: "Cross-site request rejected" } },
      { status: 403 },
    );
  }
  try {
    await consumeAuthRateLimit(request, "totp_enrollment", "read", 20);
    const account = await getPendingEnrollment(request.headers.get("cookie"));
    if (!account) {
      return noStoreJson(
        { error: { code: "enrollment_expired", message: "初始化会话已失效，请重新开始" } },
        { status: 401 },
      );
    }
    const secret = await decryptAuthSecret(
      { ciphertext: account.totpSecretCiphertext, nonce: account.totpSecretNonce },
      `admin-totp:${account.id}`,
    );
    return noStoreJson({
      username: account.username,
      secret,
      uri: createTotpUri(account.username, secret),
      expiresAt: account.enrollmentExpiresAt,
    });
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    return noStoreJson(
      { error: { code: "enrollment_unavailable", message: "无法读取 2FA 初始化信息" } },
      { status: 500 },
    );
  }
}
