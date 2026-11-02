import { parseUsageReport, recordUsage } from "../../_lib/usage-stats";

// Opt-in anonymous usage counts from the app (UsageReporter.swift). Counts only;
// the request IP is never read or stored.
export async function POST(request: Request) {
  const length = Number(request.headers.get("content-length") ?? "0");
  if (length > 16_384) return new Response("Too large", { status: 413 });
  let body: unknown;
  try {
    const text = await request.text();
    if (text.length > 16_384) return new Response("Too large", { status: 413 });
    body = JSON.parse(text);
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }
  const report = parseUsageReport(body);
  if (!report) return new Response("Invalid report", { status: 400 });
  try {
    await recordUsage(report);
  } catch (error) {
    console.error("usage report not recorded", error);
    return new Response("Unavailable", { status: 503 });
  }
  return new Response(null, { status: 204, headers: { "Cache-Control": "no-store" } });
}
