import {
  deleteCorrections,
  installIdPattern,
  parseCorrectionReport,
  recordCorrections,
} from "../../_lib/corrections";

const noStore = { "Cache-Control": "no-store" };

// Opt-in "Help improve accuracy" pairs from the app (CorrectionReporter.swift). Scrubbed again
// here; the request IP is never read or stored. decisions.md 2026-11-02.
export async function POST(request: Request) {
  const length = Number(request.headers.get("content-length") ?? "0");
  if (length > 32_768) return new Response("Too large", { status: 413 });
  let body: unknown;
  try {
    const text = await request.text();
    if (text.length > 32_768) return new Response("Too large", { status: 413 });
    body = JSON.parse(text);
  } catch {
    return new Response("Bad JSON", { status: 400 });
  }
  const report = parseCorrectionReport(body);
  if (!report) return new Response("Invalid report", { status: 400 });
  try {
    await recordCorrections(report);
  } catch (error) {
    console.error("corrections not recorded", error);
    return new Response("Unavailable", { status: 503 });
  }
  return new Response(null, { status: 204, headers: noStore });
}

// Opt-out: the app asks us to forget everything its install ID shared.
export async function DELETE(request: Request) {
  const installId = (new URL(request.url).searchParams.get("installId") ?? "").toLowerCase();
  if (!installIdPattern.test(installId)) return new Response("Invalid install ID", { status: 400 });
  try {
    await deleteCorrections(installId);
  } catch (error) {
    console.error("corrections not deleted", error);
    return new Response("Unavailable", { status: 503 });
  }
  return new Response(null, { status: 204, headers: noStore });
}
