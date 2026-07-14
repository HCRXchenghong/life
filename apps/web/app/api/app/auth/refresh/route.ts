import {
  clearAuthRateLimit,
  consumeAuthRateLimit,
  RateLimitError,
  rateLimitResponse,
} from "../../../../../lib/admin-auth";
import { rotateAppSession } from "../../../../../lib/app-auth";
import { writeAudit } from "../../../../../lib/audit";
import { noStoreJson, requireJsonRequest } from "../../../../../lib/security/http";
import { assertAllowedFields } from "../../../../../lib/security/validation";

export async function POST(request: Request) {
  const mediaFailure = requireJsonRequest(request);
  if (mediaFailure) return mediaFailure;
  try {
    const payload: unknown = await request.json();
    assertAllowedFields(payload, ["refreshToken"]);
    const refreshToken = typeof payload.refreshToken === "string" ? payload.refreshToken : "";
    await consumeAuthRateLimit(request, "app_refresh", refreshToken || "unknown", 20);
    const rotated = await rotateAppSession(refreshToken);
    if (!rotated) {
      return noStoreJson(
        { error: { code: "invalid_refresh_token", message: "登录已失效，请重新登录" } },
        { status: 401 },
      );
    }
    await clearAuthRateLimit(request, "app_refresh", refreshToken);
    await writeAudit({
      actor: `app:${rotated.accountId}`,
      action: "app.session.refresh",
      targetType: "app_session",
      outcome: "allowed",
      risk: "low",
    });
    return noStoreJson({ tokens: rotated.pair });
  } catch (error) {
    if (error instanceof RateLimitError) return rateLimitResponse(error);
    return noStoreJson(
      { error: { code: "refresh_failed", message: "刷新登录失败" } },
      { status: 500 },
    );
  }
}
