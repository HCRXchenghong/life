import { getDb } from "../db";
import { auditEvents } from "../db/schema";
import { sanitizeAuditMetadata } from "./security/audit-metadata";

type AuditInput = {
  actor: string;
  action: string;
  targetType: string;
  targetId?: string | null;
  outcome: "allowed" | "denied" | "failed";
  risk?: "read_only" | "low" | "medium" | "high" | "critical";
  requestId?: string | null;
  metadata?: Record<string, unknown>;
};

export async function writeAudit(input: AuditInput): Promise<void> {
  await getDb().insert(auditEvents).values({
    id: crypto.randomUUID(),
    actor: input.actor,
    action: input.action,
    targetType: input.targetType,
    targetId: input.targetId ?? null,
    outcome: input.outcome,
    risk: input.risk ?? "low",
    requestId: input.requestId ?? null,
    metadataJson: JSON.stringify(sanitizeAuditMetadata(input.metadata)),
  });
}
