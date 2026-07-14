import type { Metadata } from "next";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { AdminSettings } from "../../../components/AdminSettings";
import { getAdminIdentity } from "../../../lib/admin-auth";

export const metadata: Metadata = { title: "后台设置" };
export const dynamic = "force-dynamic";

export default async function AdminSettingsPage() {
  const requestHeaders = await headers();
  const identity = await getAdminIdentity(
    requestHeaders.get("cookie"),
    requestHeaders.get("user-agent"),
  );
  if (!identity) redirect("/admin");

  return <AdminSettings username={identity.username} />;
}
