import type { Metadata } from "next";
import { CopyCode } from "./copy-code";
import { UnlockSteps } from "./unlock-steps";

export const metadata: Metadata = {
  title: "Thanks for buying Rhino",
  robots: { index: false, follow: false },
};

const downloadUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/download/v0.1.52/Rhino-0.1.52.dmg";

/** The app checks this code against a SHA-256 hash in UsageGate.swift. */
const unlockCode = "RHINO-33MY-Q56S";

export default function Thanks() {
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
        <h1>Thanks for buying Rhino.</h1>
        <p className="payment-note">
          Your payment is complete. PayPal emailed you a receipt.
        </p>
        <UnlockSteps downloadUrl={downloadUrl} unlockCode={unlockCode} />
        <div className="unlock-backup">
          <p className="unlock-backup-label">Your unlock code</p>
          <CopyCode code={unlockCode} />
          <p className="unlock-backup-help">
            Only needed if the button doesn&apos;t open Rhino, or on another Mac:
            click the Rhino icon in your menu bar → <strong>Enter unlock code…</strong> →
            paste the code.
          </p>
        </div>
        <p className="install-note">
          Requires macOS 14 or later on Apple silicon. If you used Rhino before
          it went free, you are unlocked already.
        </p>
      </div>
    </main>
  );
}
