import { downloadUrl } from "../_components/site-chrome";

// "Download free" buttons land here: the browser follows the redirect and starts
// the DMG download without leaving the page it was on.
export function GET() {
  return new Response(null, {
    status: 302,
    headers: { Location: downloadUrl, "Cache-Control": "no-store" },
  });
}
