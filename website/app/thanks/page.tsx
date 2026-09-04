const downloadUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/download/v0.1.19/Rhino-0.1.19.dmg";

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
        <p>Your private Mac dictation app is ready to download.</p>
        <a className="button button-primary download-button" href={downloadUrl}>
          Download Rhino for Mac
        </a>
        <p className="install-note">
          Requires macOS 14 or later on Apple silicon. Open the DMG, drag Rhino
          to Applications, then follow the short setup.
        </p>
      </div>
    </main>
  );
}
