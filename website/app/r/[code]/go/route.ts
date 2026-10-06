import { downloadUrl } from "../../../_components/site-chrome";
import { appSumoUrl, isReferralCode, recordReferralClick } from "../../../_lib/referrals";

// A friend clicked through from a referral page: count them (once), then send them on.
export async function GET(request: Request, { params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  const to = new URL(request.url).searchParams.get("to") === "appsumo" ? "appsumo" : "download";
  if (isReferralCode(code)) {
    // Never let a counting failure cost the friend their download.
    try {
      await recordReferralClick(code, request, to);
    } catch (error) {
      console.error("referral click not recorded", error);
    }
  }
  return new Response(null, {
    status: 302,
    headers: { Location: to === "appsumo" ? appSumoUrl : downloadUrl, "Cache-Control": "no-store" },
  });
}
