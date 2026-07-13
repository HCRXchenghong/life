import { and, asc, eq } from "drizzle-orm";
import { getDb } from "../../db";
import {
  pollParticipants,
  pollVotes,
  sharePolls,
  shareSlots,
} from "../../db/schema";
import { sha256 } from "../security/encoding";

export async function loadPollByPublicToken(publicToken: string) {
  const tokenHash = await sha256(publicToken);
  const db = getDb();
  const [poll] = await db
    .select({
      id: sharePolls.id,
      title: sharePolls.title,
      description: sharePolls.description,
      timezone: sharePolls.timezone,
      status: sharePolls.status,
      closesAt: sharePolls.closesAt,
      selectedSlotId: sharePolls.selectedSlotId,
      version: sharePolls.version,
      createdAt: sharePolls.createdAt,
      updatedAt: sharePolls.updatedAt,
    })
    .from(sharePolls)
    .where(eq(sharePolls.publicTokenHash, tokenHash))
    .limit(1);
  if (!poll) return null;
  const [slots, participants, votes] = await Promise.all([
    db.select().from(shareSlots).where(eq(shareSlots.pollId, poll.id)).orderBy(asc(shareSlots.sortOrder)),
    db
      .select({
        id: pollParticipants.id,
        displayName: pollParticipants.displayName,
        createdAt: pollParticipants.createdAt,
        updatedAt: pollParticipants.updatedAt,
      })
      .from(pollParticipants)
      .where(eq(pollParticipants.pollId, poll.id))
      .orderBy(asc(pollParticipants.createdAt)),
    db
      .select({
        participantId: pollVotes.participantId,
        slotId: pollVotes.slotId,
        response: pollVotes.response,
      })
      .from(pollVotes)
      .innerJoin(pollParticipants, eq(pollParticipants.id, pollVotes.participantId))
      .where(eq(pollParticipants.pollId, poll.id)),
  ]);
  return { poll, slots, participants, votes };
}

export async function assertManageToken(pollId: string, manageToken: string): Promise<boolean> {
  const hash = await sha256(manageToken);
  const [poll] = await getDb()
    .select({ id: sharePolls.id })
    .from(sharePolls)
    .where(and(eq(sharePolls.id, pollId), eq(sharePolls.manageTokenHash, hash)))
    .limit(1);
  return Boolean(poll);
}

export function pollIsOpen(status: string, closesAt: string | null): boolean {
  if (status !== "open") return false;
  return !closesAt || new Date(closesAt).getTime() > Date.now();
}

