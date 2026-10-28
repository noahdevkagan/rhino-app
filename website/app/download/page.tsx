import type { Metadata } from "next";
import { MacDownloadGate } from "../_components/mac-check";
import { rhinoPrice } from "../_components/site-chrome";

export const metadata: Metadata = {
  title: "Download Rhino Voice for Mac (Free)",
  description:
    "Download Rhino Voice free: talk instead of typing in any Mac app, and nothing goes to the cloud. Unlimited for your first week, then 2,000 words a week free.",
  alternates: { canonical: "https://rhinovoice.app/download" },
};

export default function Download() {
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
        <h1>Download Rhino free.</h1>
        <p>
          Talk instead of typing, in any app. Nothing leaves your Mac.
          Unlimited for your first week, then 2,000 words a week, free forever.
          Want unlimited? Invite 2 friends or pay ${rhinoPrice} once, from inside
          the app.
        </p>
        <MacDownloadGate href="/get">
          <a className="button button-primary download-button" href="/get">
            Download Rhino for Mac
          </a>
        </MacDownloadGate>
        <p className="install-note">
          Open the DMG, drag Rhino to Applications, then follow the short
          setup. No account, no email.
        </p>
      </div>
    </main>
  );
}
