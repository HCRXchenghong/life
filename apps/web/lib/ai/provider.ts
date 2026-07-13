import { and, eq } from "drizzle-orm";
import { getDb } from "../../db";
import { aiProviderConfigs } from "../../db/schema";
import { decryptSecret } from "../security/secrets";

export type ProviderRecord = typeof aiProviderConfigs.$inferSelect;

export async function loadProviderForOwner(
  providerId: string,
  ownerEmail: string,
): Promise<{ provider: ProviderRecord; apiKey: string }> {
  const [provider] = await getDb()
    .select()
    .from(aiProviderConfigs)
    .where(
      and(eq(aiProviderConfigs.id, providerId), eq(aiProviderConfigs.ownerEmail, ownerEmail)),
    )
    .limit(1);
  if (!provider || !provider.enabled) throw new Error("AI provider is unavailable");
  const apiKey = await decryptSecret(
    { ciphertext: provider.apiKeyCiphertext, nonce: provider.apiKeyNonce },
    ownerEmail,
  );
  return { provider, apiKey };
}

export async function loadProviderForGateway(
  providerId: string,
  actor: string,
): Promise<{ provider: ProviderRecord; apiKey: string }> {
  const [provider] = await getDb()
    .select()
    .from(aiProviderConfigs)
    .where(and(eq(aiProviderConfigs.id, providerId), eq(aiProviderConfigs.ownerEmail, actor)))
    .limit(1);
  if (!provider || !provider.enabled) throw new Error("AI provider is unavailable");
  const apiKey = await decryptSecret(
    { ciphertext: provider.apiKeyCiphertext, nonce: provider.apiKeyNonce },
    provider.ownerEmail,
  );
  return { provider, apiKey };
}

export function publicProvider(provider: ProviderRecord) {
  return {
    id: provider.id,
    name: provider.name,
    kind: provider.kind,
    baseUrl: provider.baseUrl,
    textModel: provider.textModel,
    imageModel: provider.imageModel,
    apiKeyHint: provider.apiKeyHint,
    enabled: provider.enabled,
    createdAt: provider.createdAt,
    updatedAt: provider.updatedAt,
  };
}
