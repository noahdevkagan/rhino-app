import { correctionsSummary, isAdmin, MIN_INSTALLS } from "../../../_lib/corrections";

// Read by .github/workflows/improve-weekly.yml with the ADMIN_TOKEN secret. Returns only pairs
// taught on MIN_INSTALLS+ different Macs, never anything per install.
export async function GET(request: Request) {
  if (!isAdmin(request)) return new Response("Unauthorized", { status: 401, headers: { "Cache-Control": "no-store" } });
  try {
    const pairs = await correctionsSummary();
    return Response.json(
      { minInstalls: MIN_INSTALLS, generatedAt: new Date().toISOString(), pairs },
      { headers: { "Cache-Control": "no-store" } },
    );
  } catch (error) {
    console.error("corrections summary failed", error);
    return new Response("Unavailable", { status: 503 });
  }
}
