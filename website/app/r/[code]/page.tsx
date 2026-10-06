import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { appSumoCoupon, isReferralCode } from "../../_lib/referrals";

export const metadata: Metadata = {
  title: "A friend gave you Rhino Voice",
  description: "Private, on-device dictation for Mac. Hold Fn, speak, and release.",
  robots: { index: false, follow: false },
};

export default async function ReferralLanding({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  if (!isReferralCode(code)) notFound();
  return (
    <main className="text-page purchase-page">
      <a className="back-link" href="/">← Rhino</a>
      <div className="purchase-card">
        <span
          className="rhino-mark"
          style={{ width: 64, height: 64, fontSize: 40 }}
          aria-hidden="true"
        >
          🦏
        </span>
        <h1>A friend gave you Rhino.</h1>
        <p>
          Hold Fn, speak, and release: Rhino types what you said in any app. Transcription
          and cleanup run 100% on your Mac, even with Wi-Fi off.
        </p>
        <a className="button button-primary" href={`/r/${code}/go?to=appsumo`}>
          Get Rhino Unlimited free on AppSumo
        </a>
        <p className="install-note">
          Use coupon <code>{appSumoCoupon}</code> at checkout.
        </p>
        <a className="button download-button" href={`/r/${code}/go?to=download`}>
          Or download the free version
        </a>
        <p className="install-note">Requires macOS 14 or later on Apple silicon.</p>
      </div>
    </main>
  );
}
