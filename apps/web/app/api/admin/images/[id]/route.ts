import { env } from "cloudflare:workers";
import { and, eq } from "drizzle-orm";
import { getDb } from "../../../../../db";
import { generatedAssets } from "../../../../../db/schema";
import { requireAdmin } from "../../../../../lib/api-auth";

type ImageEnv = { GENERATED_ASSETS: R2Bucket };

export async function GET(
  _request: Request,
  context: { params: Promise<{ id: string }> },
) {
  const actor = await requireAdmin();
  if (actor instanceof Response) return actor;
  const { id } = await context.params;
  const [asset] = await getDb()
    .select()
    .from(generatedAssets)
    .where(and(eq(generatedAssets.id, id), eq(generatedAssets.ownerEmail, actor)))
    .limit(1);
  if (!asset) return Response.json({ error: { code: "not_found" } }, { status: 404 });
  const object = await (env as unknown as ImageEnv).GENERATED_ASSETS.get(asset.r2Key);
  if (!object) return Response.json({ error: { code: "asset_missing" } }, { status: 404 });
  return new Response(object.body, {
    headers: {
      "content-type": asset.contentType,
      "cache-control": "private, max-age=300",
      "x-content-type-options": "nosniff",
    },
  });
}

