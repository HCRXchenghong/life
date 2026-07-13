export async function GET() {
  return Response.json({
    status: "ok",
    service: "daylink-web",
    version: "0.1.0",
    time: new Date().toISOString(),
  });
}

