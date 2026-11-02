import { usageTotals } from "../../_lib/usage-stats";

export const dynamic = "force-dynamic";

// Public totals from installs that opted in to anonymous usage counts.
export async function GET() {
  try {
    const totals = await usageTotals();
    return Response.json(totals, {
      headers: { "Cache-Control": "public, max-age=3600", "Access-Control-Allow-Origin": "*" },
    });
  } catch (error) {
    console.error("usage totals unavailable", error);
    return Response.json({ error: "unavailable" }, { status: 503, headers: { "Cache-Control": "no-store" } });
  }
}
