const downloadUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/download/v0.1.34/Rhino-0.1.34.dmg";

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
        <ol className="unlock-steps">
          <li>
            <a className="button button-primary download-button" href={downloadUrl}>
              Download Rhino for Mac
            </a>
            <span>Open the DMG and drag Rhino to Applications.</span>
          </li>
          <li>
            <a className="button button-primary" href={`rhinovoice://unlock?code=${unlockCode}`}>
              Unlock Rhino
            </a>
            <span>Once Rhino is installed, click this. Rhino opens already unlimited.</span>
          </li>
        </ol>
        <p className="install-note">
          Requires macOS 14 or later on Apple silicon. Using Rhino on another
          Mac? Click Unlock Rhino there too, or enter your code in Rhino under
          Get Rhino Unlimited: <code>{unlockCode}</code>. If you used Rhino
          before it went free, you are unlocked already.
        </p>
      </div>
    </main>
  );
}
