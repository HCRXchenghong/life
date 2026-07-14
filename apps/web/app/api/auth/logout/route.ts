import { getAdminIdentity, revokeAdminSession } from "../../../../lib/admin-auth";
import { writeAudit } from "../../../../lib/audit";
import {
  clearPrivateCookie,
  noStoreJson,
  requireSameOriginMutation,
} from "../../../../lib/security/http";

export async function POST(request: Request) {
  const csrfFailure = requireSameOriginMutation(request);
  if (csrfFailure) return csrfFailure;
  const identity = await getAdminIdentity(
    request.headers.get("cookie"),
    request.headers.get("user-agent"),
  );
  await revokeAdminSession(request.headers.get("cookie"));
  if (identity) {
    await writeAudit({
      actor: identity.actor,
      action: "admin.logout",
      targetType: "admin_session",
      outcome: "allowed",
      risk: "low",
    });
  }
  const response = noStoreJson({ ok: true });
  response.headers.append("set-cookie", clearPrivateCookie(request, "session"));
  return response;
}
