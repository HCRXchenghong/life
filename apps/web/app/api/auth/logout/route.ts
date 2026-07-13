import { revokeAdminSession } from "../../../../lib/admin-auth";
import {
  clearPrivateCookie,
  noStoreJson,
  requireSameOriginMutation,
} from "../../../../lib/security/http";

export async function POST(request: Request) {
  const csrfFailure = requireSameOriginMutation(request);
  if (csrfFailure) return csrfFailure;
  await revokeAdminSession(request.headers.get("cookie"));
  const response = noStoreJson({ ok: true });
  response.headers.append("set-cookie", clearPrivateCookie(request, "session"));
  return response;
}
