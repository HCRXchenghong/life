import { and, eq } from "drizzle-orm";
import { getDb } from "../../../../../db";
import { sharePolls, shareSlots } from "../../../../../db/schema";
import { writeAudit } from "../../../../../lib/audit";
import { assertManageToken, loadPollByPublicToken } from "../../../../../lib/polls/service";
import { errorResponse, requiredText } from "../../../../../lib/security/validation";

export async function POST(
  request: Request,
  context: { params: Promise<{ token: string }> },
) {
  try {
    const { token } = await context.params;
    const result = await loadPollByPublicToken(token);
    if (!result) return Response.json({ error: { code: "not_found" } }, { status: 404 });
    const payload = (await request.json()) as Record<string, unknown>;
    const manageToken = requiredText(payload.manageToken, "manageToken", 160);
    const slotId = requiredText(payload.slotId, "slotId", 64);
    const expectedVersion = payload.expectedVersion;
    if (
      typeof expectedVersion !== "number" ||
      !Number.isSafeInteger(expectedVersion) ||
      expectedVersion < 1
    ) {
      throw new Error("expectedVersion must be a positive integer");
    }
    if (expectedVersion !== result.poll.version) {
      return Response.json(
        { error: { code: "version_conflict", message: "Poll changed; reload and retry" } },
        { status: 409 },
      );
    }
    if (!(await assertManageToken(result.poll.id, manageToken))) {
      return Response.json({ error: { code: "invalid_manage_token" } }, { status: 403 });
    }
    const [slot] = await getDb()
      .select()
      .from(shareSlots)
      .where(and(eq(shareSlots.id, slotId), eq(shareSlots.pollId, result.poll.id)))
      .limit(1);
    if (!slot) throw new Error("Selected slot does not belong to this poll");
    const now = new Date().toISOString();
    const [updated] = await getDb()
      .update(sharePolls)
      .set({
        status: "closed",
        selectedSlotId: slotId,
        version: expectedVersion + 1,
        updatedAt: now,
      })
      .where(and(eq(sharePolls.id, result.poll.id), eq(sharePolls.version, expectedVersion)))
      .returning({ id: sharePolls.id, version: sharePolls.version });
    if (!updated) {
      return Response.json(
        { error: { code: "version_conflict", message: "Poll changed; reload and retry" } },
        { status: 409 },
      );
    }
    await writeAudit({
      actor: `poll-manager:${result.poll.id}`,
      action: "poll.finalize",
      targetType: "share_poll",
      targetId: result.poll.id,
      outcome: "allowed",
      risk: "medium",
      metadata: { slotId },
    });
    return Response.json({ pollId: result.poll.id, version: updated.version, selectedSlot: slot });
  } catch (error) {
    return errorResponse(error);
  }
}
