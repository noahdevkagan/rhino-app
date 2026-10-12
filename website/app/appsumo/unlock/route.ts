// Email clients strip rhinovoice:// links, so the "Unlock Rhino" button in the code email
// points here and we hand off to the app. Rhino checks the code itself.
export async function GET(request: Request) {
  const code = (new URL(request.url).searchParams.get("code") ?? "").trim().toUpperCase().replace(/\s+/g, "").slice(0, 24);
  return new Response(null, {
    status: 302,
    headers: { Location: `rhinovoice://unlock?code=${encodeURIComponent(code)}`, "Cache-Control": "no-store" },
  });
}
