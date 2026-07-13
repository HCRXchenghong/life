import { desc, eq } from "drizzle-orm";
import { getD1, getDb } from "../../../db";
import { sharePolls } from "../../../db/schema";
import { requireOperator } from "../../../lib/api-auth";
import { writeAudit } from "../../../lib/audit";
import { randomToken, sha256 } from "../../../lib/security/encoding";
import {
  errorResponse,
  isoInstant,
  optionalText,
  requiredText,
} from "../../../lib/security/validation";

export async function GET(request: Request) {
  const actor = await requireOperator(request);
  if (actor instanceof Response) return actor;
  const polls = await getDb()
    .select({
      id: sharePolls.id,
      title: sharePolls.title,
      timezone: sharePolls.timezone,
      status: sharePolls.status,
      closesAt: sharePolls.closesAt,
      selectedSlotId: sharePolls.selectedSlotId,
      version: sharePolls.version,
      createdAt: sharePolls.createdAt,
      updatedAt: sharePolls.updatedAt,
    })
    .from(sharePolls)
    .where(eq(sharePolls.createdBy, actor))
    .orderBy(desc(sharePolls.createdAt))
    .limit(100);
  return Response.json({ polls });
}

export async function POST(request: Request) {
  const actor = await requireOperator(request);
  if (actor instanceof Response) return actor;
  try {
    const payload = (await request.json()) as Record<string, unknown>;
    const title = requiredText(payload.title, "title", 160);
    const description = optionalText(payload.description, "description", 2000) ?? "";
    const timezone = requiredText(payload.timezone, "timezone", 80);
    assertTimezone(timezone);
    const closesAt = payload.closesAt ? isoInstant(payload.closesAt, "closesAt") : null;
    const slots = parseSlots(payload.slots);
    const pollId = crypto.randomUUID();
    const publicToken = randomToken();
    const manageToken = randomToken();
    const now = new Date().toISOString();
    const d1 = getD1();
    await d1.batch([
      d1
        .prepare(
          `INSERT INTO share_polls
          (id, created_by, title, description, timezone, public_token_hash, manage_token_hash,
           status, closes_at, version, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, 'open', ?, 1, ?, ?)`,
        )
        .bind(
          pollId,
          actor,
          title,
          description,
          timezone,
          await sha256(publicToken),
          await sha256(manageToken),
          closesAt,
          now,
          now,
        ),
      ...slots.map((slot, index) =>
        d1
          .prepare(
            `INSERT INTO share_slots
             (id, poll_id, label, starts_at, ends_at, sort_order, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?)`,
          )
          .bind(slot.id, pollId, slot.label, slot.startsAt, slot.endsAt, index, now),
      ),
    ]);
    await writeAudit({
      actor,
      action: "poll.create",
      targetType: "share_poll",
      targetId: pollId,
      outcome: "allowed",
      risk: "low",
      metadata: { slotCount: slots.length },
    });
    const origin = new URL(request.url).origin;
    return Response.json(
      {
        poll: {
          id: pollId,
          publicToken,
          manageToken,
          inviteUrl: `${origin}/poll/${publicToken}`,
          status: "open",
          version: 1,
        },
      },
      { status: 201 },
    );
  } catch (error) {
    return errorResponse(error);
  }
}

function parseSlots(value: unknown) {
  if (!Array.isArray(value) || value.length < 2 || value.length > 30) {
    throw new Error("slots must contain between 2 and 30 candidates");
  }
  const seen = new Set<string>();
  return value.map((entry, index) => {
    if (!entry || typeof entry !== "object") throw new Error(`slots[${index}] is invalid`);
    const record = entry as Record<string, unknown>;
    const startsAt = isoInstant(record.startsAt, `slots[${index}].startsAt`);
    const endsAt = isoInstant(record.endsAt, `slots[${index}].endsAt`);
    if (new Date(endsAt) <= new Date(startsAt)) throw new Error(`slots[${index}] must end after start`);
    const key = `${startsAt}/${endsAt}`;
    if (seen.has(key)) throw new Error("Duplicate slot");
    seen.add(key);
    return {
      id: crypto.randomUUID(),
      label: optionalText(record.label, `slots[${index}].label`, 120) ?? "",
      startsAt,
      endsAt,
    };
  });
}

function assertTimezone(value: string) {
  try {
    new Intl.DateTimeFormat("en", { timeZone: value }).format();
  } catch {
    throw new Error("timezone must be a valid IANA time zone");
  }
}

