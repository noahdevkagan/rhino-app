const paypalAction = "https://www.paypal.com/cgi-bin/webscr";
const releasesUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases";

function RhinoMark({ size = 42 }: { size?: number }) {
  return (
    <span
      className="rhino-mark"
      style={{ width: size, height: size, fontSize: Math.round(size * 0.62) }}
      aria-hidden="true"
    >
      🦏
    </span>
  );
}

function BuyForm({ compact = false }: { compact?: boolean }) {
  return (
    <form className={compact ? "buy-form buy-form-compact" : "buy-form"} action={paypalAction} method="post">
      <input type="hidden" name="cmd" value="_xclick" />
      <input type="hidden" name="business" value="paypal@okdork.com" />
      <input type="hidden" name="item_name" value="Rhino for Mac" />
      <input type="hidden" name="amount" value="20.00" />
      <input type="hidden" name="currency_code" value="USD" />
      <input type="hidden" name="no_shipping" value="1" />
      <input type="hidden" name="return" value="https://rhinovoice.app/thanks" />
      <input type="hidden" name="cancel_return" value="https://rhinovoice.app/" />
      <button className={compact ? "button button-compact" : "button button-primary"} type="submit">
        {compact ? "Buy — $20" : "Buy Rhino — $20"}
      </button>
    </form>
  );
}

export default function Home() {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Rhino",
    operatingSystem: "macOS 14 or later",
    applicationCategory: "BusinessApplication",
    description:
      "Rhino is a private dictation app for Mac with on-device transcription and optional local AI cleanup.",
    url: "https://rhinovoice.app/",
    author: { "@type": "Person", name: "Noah Kagan" },
    offers: {
      "@type": "Offer",
      price: "20.00",
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
    },
  };

  return (
    <div className="home-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <header className="site-header">
        <a className="brand" href="/" aria-label="Rhino home">
          <RhinoMark />
          <span>Rhino</span>
        </a>
        <nav aria-label="Main navigation">
          <a href="/changelog">Changelog</a>
          <BuyForm compact />
        </nav>
      </header>

      <main className="hero" id="main">
        <div className="hero-copy">
          <p className="eyebrow">
            <span className="status-dot" aria-hidden="true" />
            For macOS 14+ · Signed &amp; notarized
          </p>
          <h1>
            Talk. Rhino types.
            <span>Nothing leaves your Mac.</span>
          </h1>
          <p className="hero-description">
            Hold Fn, speak naturally, and release. Rhino turns your voice into
            polished text in whatever app you&apos;re using. Transcription and AI
            cleanup run 100% on your Mac—even with Wi-Fi off.
          </p>
          <BuyForm />
          <p className="purchase-note">
            One-time purchase via PayPal. No subscription, no account.
            <br />30-day money-back guarantee.
          </p>
        </div>

        <div className="hero-visual" aria-label="Rhino dictating into a document">
          <div className="app-window">
            <div className="window-bar">
              <div className="traffic-lights" aria-hidden="true">
                <span />
                <span />
                <span />
              </div>
              <span>Launch update</span>
              <span className="share-pill">Share</span>
            </div>
            <div className="editor">
              <span className="document-label">TEAM NOTES</span>
              <h2>Tuesday launch update</h2>
              <p>
                Hey team, quick update—the launch brief is ready for review. I
                added the final screenshots and moved our kickoff to 4pm.
                <span className="caret" aria-hidden="true" />
              </p>
            </div>
          </div>
          <div className="dictation-pill">
            <RhinoMark size={38} />
            <div className="waveform" aria-hidden="true">
              <i /><i /><i /><i /><i /><i /><i /><i /><i />
            </div>
            <span>Release Fn to insert</span>
          </div>
          <div className="local-badge">
            <span aria-hidden="true">✓</span>
            Processed on this Mac
          </div>
        </div>
      </main>

      <footer>
        <span>Rhino</span>
        <a href="mailto:noahkagan@gmail.com">Email</a>
        <a href="/changelog">Changelog</a>
        <a href={releasesUrl}>Releases on GitHub</a>
      </footer>
    </div>
  );
}
