import { requireAppIdentity, revokeAppSession } from "../../../../../lib/app-auth";
import { writeAudit } from "../../../../../lib/audit";
import { noStoreJson } from "../../../../../lib/security/http";

export async function GET(request: Request) {
  const identity = await requireAppIdentity(request);
  if (identity instanceof Response) return identity;
  return noStoreJson({
    account: {
      id: identity.accountId,
      username: identity.username,
      passwordChangeRequired: identity.passwordChangeRequired,
    },
  });
}

export async function DELETE(request: Request) {
  const identity = await requireAppIdentity(request);
  if (identity instanceof Response) return identity;
  await revokeAppSession(identity.sessionId);
  await writeAudit({
    actor: `app:${identity.accountId}`,
    action: "app.logout",
    targetType: "app_session",
    targetId: identity.sessionId,
    outcome: "allowed",
    risk: "low",
  });
  return noStoreJson({ loggedOut: true });
}
