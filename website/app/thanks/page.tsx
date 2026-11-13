import type { Metadata } from "next";
import { CopyCode } from "./copy-code";

export const metadata: Metadata = {
  title: "Thanks for buying Rhino",
  robots: { index: false, follow: false },
};

const downloadUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/download/v0.1.50/Rhino-0.1.50.dmg";

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
        <ol className="unlock-steps">
          <li>
            <a className="button button-primary download-button" href={downloadUrl}>
              Download Rhino for Mac
            </a>
            <span>Open the DMG and drag Rhino to Applications. Already have Rhino? Skip to step 2.</span>
          </li>
          <li>
            <a className="button button-primary" href={`rhinovoice://unlock?code=${unlockCode}`}>
              Unlock Rhino
            </a>
            <span>One click. Nothing to type. Rhino opens and says it&apos;s unlimited.</span>
          </li>
        </ol>
        <div className="unlock-backup">
          <p className="unlock-backup-label">Your unlock code</p>
          <CopyCode code={unlockCode} />
          <p className="unlock-backup-help">
            Only needed if the button doesn&apos;t open Rhino, or on another Mac:
            click the Rhino icon in your menu bar → <strong>Get Rhino Unlimited</strong> →
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
