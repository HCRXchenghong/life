type AuditValue = string | number | boolean | null | AuditValue[] | { [key: string]: AuditValue };

const SENSITIVE_KEY =
  /(password|passphrase|api.?key|secret|token|authorization|private.?key|command.?output|raw.?output|prompt|input|content|message)/i;
const SAFE_KEY = /^[A-Za-z][A-Za-z0-9_.-]{0,63}$/;
const MAX_KEYS = 32;
const MAX_ARRAY_ITEMS = 32;
const MAX_STRING_LENGTH = 256;
const MAX_DEPTH = 3;

export function sanitizeAuditMetadata(
  metadata: Record<string, unknown> | undefined,
): Record<string, AuditValue> {
  if (!metadata) return {};
  const output: Record<string, AuditValue> = {};
  for (const [key, value] of Object.entries(metadata).slice(0, MAX_KEYS)) {
    if (!SAFE_KEY.test(key) || SENSITIVE_KEY.test(key)) continue;
    const safeValue = sanitizeValue(value, 0);
    if (safeValue !== undefined) output[key] = safeValue;
  }
  return output;
}

function sanitizeValue(value: unknown, depth: number): AuditValue | undefined {
  if (value === null || typeof value === "boolean") return value;
  if (typeof value === "number") return Number.isFinite(value) ? value : undefined;
  if (typeof value === "string") {
    return value.replace(/[\u0000-\u001f\u007f]/g, "").slice(0, MAX_STRING_LENGTH);
  }
  if (depth >= MAX_DEPTH) return undefined;
  if (Array.isArray(value)) {
    return value
      .slice(0, MAX_ARRAY_ITEMS)
      .map((item) => sanitizeValue(item, depth + 1))
      .filter((item): item is AuditValue => item !== undefined);
  }
  if (!value || typeof value !== "object") return undefined;
  const output: Record<string, AuditValue> = {};
  for (const [key, child] of Object.entries(value).slice(0, MAX_KEYS)) {
    if (!SAFE_KEY.test(key) || SENSITIVE_KEY.test(key)) continue;
    const safeValue = sanitizeValue(child, depth + 1);
    if (safeValue !== undefined) output[key] = safeValue;
  }
  return output;
}
