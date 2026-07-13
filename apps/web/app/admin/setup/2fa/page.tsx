import type { Metadata } from "next";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { AdminTotpSetup } from "../../../../components/AdminTotpSetup";
import { getAdminIdentity, getPendingEnrollment } from "../../../../lib/admin-auth";

export const metadata: Metadata = { title: "绑定双重验证" };
export const dynamic = "force-dynamic";

export default async function AdminTotpSetupPage() {
  const requestHeaders = await headers();
  const cookieHeader = requestHeaders.get("cookie");
  const identity = await getAdminIdentity(cookieHeader, requestHeaders.get("user-agent"));
  if (identity) redirect("/admin");

  const enrollment = await getPendingEnrollment(cookieHeader);
  if (!enrollment) redirect("/admin");
  return <AdminTotpSetup />;
}
