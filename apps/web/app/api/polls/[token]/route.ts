import { loadPollByPublicToken } from "../../../../lib/polls/service";

export async function GET(
  _request: Request,
  context: { params: Promise<{ token: string }> },
) {
  const { token } = await context.params;
  if (token.length < 20 || token.length > 100) {
    return Response.json({ error: { code: "not_found" } }, { status: 404 });
  }
  const result = await loadPollByPublicToken(token);
  if (!result) return Response.json({ error: { code: "not_found" } }, { status: 404 });
  return Response.json(result, {
    headers: { "cache-control": "no-store", "referrer-policy": "no-referrer" },
  });
}

