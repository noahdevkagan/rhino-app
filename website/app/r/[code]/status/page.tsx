import type { Metadata } from "next";
import { notFound } from "next/navigation";
import { isReferralCode, referralCount, referralsNeeded, unlockCode } from "../../../_lib/referrals";

export const dynamic = "force-dynamic";

export const metadata: Metadata = {
  title: "Your Rhino invites",
  robots: { index: false, follow: false },
};

export default async function ReferralStatus({ params }: { params: Promise<{ code: string }> }) {
  const { code } = await params;
  if (!isReferralCode(code)) notFound();
  const count = Math.min(await referralCount(code), referralsNeeded);
  const done = count >= referralsNeeded;
  const link = `https://rhinovoice.app/r/${code}`;
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
        {done ? (
          <>
            <h1>You unlocked Rhino Unlimited.</h1>
            <p>Three friends got Rhino through your link. Thank you.</p>
            <a className="button button-primary" href={`rhinovoice://unlock?code=${unlockCode}`}>
              Unlock Rhino
            </a>
            <p className="install-note">Click on the Mac where Rhino is installed. Rhino opens already unlimited.</p>
          </>
        ) : (
          <>
            <h1>
              {count} of {referralsNeeded} friends
            </h1>
            <p>
              When {referralsNeeded} friends get Rhino through your link, Rhino Unlimited is
              yours free. Your link:
            </p>
            <p>
              <code>{link}</code>
            </p>
            <p className="install-note">
              A friend counts once they open your link and click to get Rhino. Check back here
              any time.
            </p>
          </>
        )}
      </div>
    </main>
  );
}
