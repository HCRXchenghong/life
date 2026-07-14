import type { Metadata } from "next";
import { count, eq } from "drizzle-orm";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { AdminOverview } from "../../components/AdminOverview";
import {
  AdminLoginForm,
  AdminSetupForm,
  PendingSetupNotice,
} from "../../components/AdminSetupForm";
import { getAdminIdentity, getBootstrapState } from "../../lib/admin-auth";
import { getDb } from "../../db";
import { aiProviderConfigs, appAccounts } from "../../db/schema";

export const metadata: Metadata = { title: "后台管理" };
export const dynamic = "force-dynamic";

export default async function AdminPage() {
  const requestHeaders = await headers();
  const cookieHeader = requestHeaders.get("cookie");
  const identity = await getAdminIdentity(cookieHeader, requestHeaders.get("user-agent"));
  if (identity) {
    const [[providerCount], [appAccountCount]] = await Promise.all([
      getDb()
        .select({ value: count() })
        .from(aiProviderConfigs)
        .where(eq(aiProviderConfigs.ownerEmail, identity.actor)),
      getDb().select({ value: count() }).from(appAccounts),
    ]);
    return (
      <AdminOverview
        username={identity.username}
        aiProviderCount={providerCount?.value ?? 0}
        appAccountCount={appAccountCount?.value ?? 0}
      />
    );
  }

  const bootstrap = await getBootstrapState(cookieHeader);
  if (bootstrap.kind === "uninitialized") {
    return <AdminSetupForm />;
  }
  if (bootstrap.kind === "pending") {
    if (bootstrap.enrollmentAuthorized) redirect("/admin/setup/2fa");
    return <PendingSetupNotice authorized={bootstrap.enrollmentAuthorized} />;
  }
  return <AdminLoginForm />;
}
