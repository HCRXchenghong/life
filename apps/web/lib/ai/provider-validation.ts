import {
  assertAllowedFields,
  optionalSecret,
  optionalText,
  parseHttpsBaseUrl,
  requiredText,
} from "../security/validation";

const PROVIDER_KINDS = new Set([
  "openai_responses",
  "openai_compatible",
  "anthropic_compatible",
]);
const MODEL_ID = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,119}$/;
const PROVIDER_ID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export type ProviderMutation = {
  id: string | null;
  name: string;
  kind: "openai_responses" | "openai_compatible" | "anthropic_compatible";
  baseUrl: string;
  textModel: string;
  imageModel: string | null;
  apiKey: string | null;
  enabled: boolean;
};

export function validateProviderMutation(value: unknown): ProviderMutation {
  assertAllowedFields(value, [
    "id",
    "name",
    "kind",
    "baseUrl",
    "textModel",
    "imageModel",
    "apiKey",
    "enabled",
  ]);
  const id = optionalText(value.id, "id", 64);
  if (id && !PROVIDER_ID.test(id)) throw new Error("Invalid Provider id");
  const kind = requiredText(value.kind, "kind", 40);
  if (!PROVIDER_KINDS.has(kind)) throw new Error("Unsupported AI provider kind");
  const textModel = validateModelId(requiredText(value.textModel, "textModel", 120), "textModel");
  const rawImageModel = optionalText(value.imageModel, "imageModel", 120);
  const imageModel = rawImageModel ? validateModelId(rawImageModel, "imageModel") : null;
  const enabled = value.enabled === undefined ? true : value.enabled;
  if (typeof enabled !== "boolean") throw new Error("enabled must be a boolean");
  return {
    id,
    name: requiredText(value.name, "name", 80),
    kind: kind as ProviderMutation["kind"],
    baseUrl: parseHttpsBaseUrl(requiredText(value.baseUrl, "baseUrl", 400)),
    textModel,
    imageModel,
    apiKey: optionalSecret(value.apiKey, "apiKey", 4_096),
    enabled,
  };
}

export function validateProviderId(value: unknown): string {
  const id = requiredText(value, "providerId", 64);
  if (!PROVIDER_ID.test(id)) throw new Error("Invalid Provider id");
  return id;
}

function validateModelId(value: string, field: string): string {
  if (!MODEL_ID.test(value)) throw new Error(`${field} contains unsupported characters`);
  return value;
}
