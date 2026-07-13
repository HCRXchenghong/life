import { and, eq } from "drizzle-orm";
import { getD1, getDb } from "../../../../../db";
import {
  pollParticipants,
} from "../../../../../db/schema";
import { randomToken, sha256 } from "../../../../../lib/security/encoding";
import { loadPollByPublicToken, pollIsOpen } from "../../../../../lib/polls/service";
import { errorResponse, optionalText, requiredText } from "../../../../../lib/security/validation";

const RESPONSES = new Set(["yes", "maybe", "no"]);

export async function POST(
  request: Request,
  context: { params: Promise<{ token: string }> },
) {
  try {
    const { token } = await context.params;
    const publicPoll = await loadPollByPublicToken(token);
    if (!publicPoll) return Response.json({ error: { code: "not_found" } }, { status: 404 });
    if (!pollIsOpen(publicPoll.poll.status, publicPoll.poll.closesAt)) {
      return Response.json(
        { error: { code: "poll_closed", message: "This poll is closed" } },
        { status: 409 },
      );
    }

    const payload = (await request.json()) as Record<string, unknown>;
    const displayName = requiredText(payload.displayName, "displayName", 80);
    const suppliedEditToken =
      optionalText(payload.editToken, "editToken", 160) ?? readEditTokenCookie(request);
    const votes = parseVotes(payload.votes, new Set(publicPoll.slots.map((slot) => slot.id)));
    const now = new Date().toISOString();
    const db = getDb();
    let participantId: string;
    let editToken: string;

    if (suppliedEditToken) {
      const editTokenHash = await sha256(suppliedEditToken);
      const [participant] = await db
        .select({ id: pollParticipants.id })
        .from(pollParticipants)
        .where(
          and(
            eq(pollParticipants.pollId, publicPoll.poll.id),
            eq(pollParticipants.editTokenHash, editTokenHash),
          ),
        )
        .limit(1);
      if (!participant) {
        return Response.json(
          { error: { code: "invalid_edit_token", message: "Edit token is invalid" } },
          { status: 403 },
        );
      }
      participantId = participant.id;
      editToken = suppliedEditToken;
    } else {
      participantId = crypto.randomUUID();
      editToken = randomToken();
    }

    const d1 = getD1();
    const statements: D1PreparedStatement[] = [];
    if (suppliedEditToken) {
      statements.push(
        d1
          .prepare(
            "UPDATE poll_participants SET display_name = ?, updated_at = ? WHERE id = ? AND poll_id = ?",
          )
          .bind(displayName, now, participantId, publicPoll.poll.id),
      );
    } else {
      statements.push(
        d1
          .prepare(
            `INSERT INTO poll_participants
             (id, poll_id, display_name, edit_token_hash, created_at, updated_at)
             VALUES (?, ?, ?, ?, ?, ?)`,
          )
          .bind(
            participantId,
            publicPoll.poll.id,
            displayName,
            await sha256(editToken),
            now,
            now,
          ),
      );
    }
    statements.push(
      d1.prepare("DELETE FROM poll_votes WHERE participant_id = ?").bind(participantId),
      ...votes.map((vote) =>
        d1
          .prepare(
            `INSERT INTO poll_votes (participant_id, slot_id, response, updated_at)
             VALUES (?, ?, ?, ?)`,
          )
          .bind(participantId, vote.slotId, vote.response, now),
      ),
    );
    await d1.batch(statements);
    return Response.json(
      {
        participant: { id: participantId, displayName },
        editToken,
        version: publicPoll.poll.version,
      },
      {
        status: suppliedEditToken ? 200 : 201,
        headers: {
          "set-cookie": `daylink_poll_edit=${encodeURIComponent(editToken)}; Path=/api/polls/${encodeURIComponent(token)}; HttpOnly; Secure; SameSite=Lax; Max-Age=2592000`,
        },
      },
    );
  } catch (error) {
    return errorResponse(error);
  }
}

function readEditTokenCookie(request: Request): string | null {
  const cookie = request.headers.get("cookie");
  if (!cookie) return null;
  for (const part of cookie.split(";")) {
    const [name, ...value] = part.trim().split("=");
    if (name === "daylink_poll_edit") {
      try {
        return decodeURIComponent(value.join("="));
      } catch {
        return null;
      }
    }
  }
  return null;
}

function parseVotes(value: unknown, slotIds: Set<string>) {
  if (!Array.isArray(value) || value.length === 0) throw new Error("votes is required");
  const seen = new Set<string>();
  return value.map((entry, index) => {
    if (!entry || typeof entry !== "object") throw new Error(`votes[${index}] is invalid`);
    const record = entry as Record<string, unknown>;
    const slotId = requiredText(record.slotId, `votes[${index}].slotId`, 64);
    const response = requiredText(record.response, `votes[${index}].response`, 16);
    if (!slotIds.has(slotId) || seen.has(slotId)) throw new Error("Vote contains an invalid slot");
    if (!RESPONSES.has(response)) throw new Error("Vote response must be yes, maybe, or no");
    seen.add(slotId);
    return { slotId, response };
  });
}
