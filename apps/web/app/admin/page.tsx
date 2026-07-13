import type { Metadata } from "next";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { AdminConsole } from "../../components/AdminConsole";
import {
  AdminLoginForm,
  AdminSetupForm,
  PendingSetupNotice,
} from "../../components/AdminSetupForm";
import { getAdminIdentity, getBootstrapState } from "../../lib/admin-auth";

export const metadata: Metadata = { title: "后台管理" };
export const dynamic = "force-dynamic";

export default async function AdminPage() {
  const requestHeaders = await headers();
  const cookieHeader = requestHeaders.get("cookie");
  const identity = await getAdminIdentity(cookieHeader, requestHeaders.get("user-agent"));
  if (identity) {
    return <AdminConsole user={{ displayName: identity.username, email: "本地管理员" }} />;
  }

  const bootstrap = await getBootstrapState(cookieHeader);
  if (bootstrap.kind === "uninitialized") return <AdminSetupForm />;
  if (bootstrap.kind === "pending") {
    if (bootstrap.enrollmentAuthorized) redirect("/admin/setup/2fa");
    return <PendingSetupNotice authorized={bootstrap.enrollmentAuthorized} />;
  }
  return <AdminLoginForm />;
}
