import type { Metadata } from "next";
import { desc } from "drizzle-orm";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { AdminAccounts } from "../../../components/AdminAccounts";
import { getDb } from "../../../db";
import { appAccounts } from "../../../db/schema";
import { getAdminIdentity } from "../../../lib/admin-auth";

export const metadata: Metadata = { title: "App 账号" };
export const dynamic = "force-dynamic";

export default async function AdminAccountsPage() {
  const requestHeaders = await headers();
  const identity = await getAdminIdentity(
    requestHeaders.get("cookie"),
    requestHeaders.get("user-agent"),
  );
  if (!identity) redirect("/admin");

  const accounts = await getDb()
    .select({
      id: appAccounts.id,
      username: appAccounts.username,
      status: appAccounts.status,
      passwordChangeRequired: appAccounts.passwordChangeRequired,
      lockedUntil: appAccounts.lockedUntil,
      lastLoginAt: appAccounts.lastLoginAt,
      createdAt: appAccounts.createdAt,
    })
    .from(appAccounts)
    .orderBy(desc(appAccounts.createdAt));

  return <AdminAccounts username={identity.username} accounts={accounts} />;
}
