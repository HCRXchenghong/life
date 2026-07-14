import type { Metadata } from "next";
import { desc, eq } from "drizzle-orm";
import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { AdminAiSettings } from "../../../components/AdminAiSettings";
import { getDb } from "../../../db";
import { aiProviderConfigs } from "../../../db/schema";
import { getAdminIdentity } from "../../../lib/admin-auth";

export const metadata: Metadata = { title: "AI 配置" };
export const dynamic = "force-dynamic";

export default async function AdminAiPage() {
  const requestHeaders = await headers();
  const identity = await getAdminIdentity(
    requestHeaders.get("cookie"),
    requestHeaders.get("user-agent"),
  );
  if (!identity) redirect("/admin");

  const providers = await getDb()
    .select({
      id: aiProviderConfigs.id,
      name: aiProviderConfigs.name,
      kind: aiProviderConfigs.kind,
      baseUrl: aiProviderConfigs.baseUrl,
      textModel: aiProviderConfigs.textModel,
      imageModel: aiProviderConfigs.imageModel,
      apiKeyHint: aiProviderConfigs.apiKeyHint,
      enabled: aiProviderConfigs.enabled,
      updatedAt: aiProviderConfigs.updatedAt,
    })
    .from(aiProviderConfigs)
    .where(eq(aiProviderConfigs.ownerEmail, identity.actor))
    .orderBy(desc(aiProviderConfigs.updatedAt));

  return <AdminAiSettings username={identity.username} providers={providers} />;
}
