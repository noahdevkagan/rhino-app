import type { Metadata } from "next";
import { rhinoPrice } from "../_components/site-chrome";

const downloadUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/download/v0.1.32/Rhino-0.1.32.dmg";

export const metadata: Metadata = {
  title: "Download Rhino Voice for Mac (Free)",
  description:
    "Download Rhino Voice free: private, on-device dictation for Mac. Unlimited for your first week, then 2,000 words a week free.",
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
          Unlimited for your first week, then 2,000 words a week, free forever.
          Want unlimited? ${rhinoPrice} once, from inside the app.
        </p>
        <a className="button button-primary download-button" href={downloadUrl}>
          Download Rhino for Mac
        </a>
        <p className="install-note">
          Requires macOS 14 or later on Apple silicon. Open the DMG, drag Rhino
          to Applications, then follow the short setup. No account, no email.
        </p>
      </div>
    </main>
  );
}
