const downloadUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/download/v0.1.2/Rhino-0.1.2.dmg";

const releasesUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/latest";

function DownloadButton({ compact = false }: { compact?: boolean }) {
  return (
    <a
      className={compact ? "button button-compact" : "button button-primary"}
      href={downloadUrl}
    >
      <span className="download-mark" aria-hidden="true">
        ↓
      </span>
      {compact ? "Download" : "Download Rhino for Mac"}
    </a>
  );
}

export default function Home() {
  return (
    <>
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <header className="site-header">
        <a className="brand" href="#top" aria-label="Rhino home">
          <img src="/rhino-icon.png" alt="" width="42" height="42" />
          <span>Rhino</span>
        </a>
        <nav aria-label="Main navigation">
          <a href="#how-it-works">How it works</a>
          <a href="#privacy">Privacy</a>
          <a href="#questions">Questions</a>
        </nav>
        <DownloadButton compact />
      </header>

      <main id="main">
        <section className="hero" id="top">
          <div className="hero-copy">
            <p className="eyebrow">
              <span className="status-dot" aria-hidden="true" />
              Private dictation for Mac
            </p>
            <h1>
              Talk. Rhino types.
              <span>Nothing leaves your Mac.</span>
            </h1>
            <p className="hero-description">
              Hold Fn, speak naturally, and release. Rhino turns your voice
              into polished text in whatever app you&apos;re using—all on your
              computer.
            </p>
            <div className="hero-actions">
              <DownloadButton />
              <a className="button button-secondary" href="#how-it-works">
                See how it works
              </a>
            </div>
            <div className="download-details" aria-label="System requirements">
              <span>macOS 14+</span>
              <span>Apple silicon</span>
              <span>Signed &amp; notarized</span>
              <span>14 MB</span>
            </div>
          </div>

          <div className="hero-visual" aria-label="Rhino dictating into a document">
            <div className="app-window">
              <div className="window-bar">
                <div className="traffic-lights" aria-hidden="true">
                  <span />
                  <span />
                  <span />
                </div>
                <span className="window-title">Launch update</span>
                <span className="share-pill">Share</span>
              </div>
              <div className="editor">
                <span className="document-label">TEAM NOTES</span>
                <h2>Tuesday launch update</h2>
                <p>
                  Hey team, quick update—the launch brief is ready for review.
                  I added the final screenshots and moved our kickoff to 4pm.
                  <span className="caret" aria-hidden="true" />
                </p>
              </div>
            </div>
            <div className="dictation-pill">
              <img src="/rhino-icon.png" alt="" width="38" height="38" />
              <div className="waveform" aria-hidden="true">
                <i />
                <i />
                <i />
                <i />
                <i />
                <i />
                <i />
                <i />
                <i />
              </div>
              <span>Release Fn to insert</span>
            </div>
            <div className="local-badge">
              <span aria-hidden="true">✓</span>
              Processed on this Mac
            </div>
          </div>
        </section>

        <section className="promise-strip" aria-label="Rhino promises">
          <p>No account</p>
          <span aria-hidden="true">•</span>
          <p>No subscription</p>
          <span aria-hidden="true">•</span>
          <p>No telemetry</p>
          <span aria-hidden="true">•</span>
          <p>No cloud transcription</p>
        </section>

        <section className="section feature-section">
          <div className="section-heading">
            <p className="eyebrow">Built for everyday writing</p>
            <h2>Your voice, ready to use anywhere.</h2>
            <p>
              Dictate the thought while it&apos;s fresh. Rhino handles the typing
              without adding another tab, account, or workflow.
            </p>
          </div>

          <div className="feature-grid">
            <article className="feature-card feature-card-wide">
              <div className="feature-icon" aria-hidden="true">⌨</div>
              <h3>Works wherever you type</h3>
              <p>
                Mail, Messages, Notes, Slack, Notion, your browser—if there is a
                text cursor, Rhino can put your words there.
              </p>
              <div className="app-row" aria-label="Example apps">
                <span>Mail</span>
                <span>Messages</span>
                <span>Notes</span>
                <span>Slack</span>
                <span>Notion</span>
              </div>
            </article>

            <article className="feature-card">
              <div className="feature-icon" aria-hidden="true">Aa</div>
              <h3>Your words, spelled right</h3>
              <p>
                Add names, products, and industry jargon to your personal
                dictionary so Rhino learns the words that matter to you.
              </p>
            </article>

            <article className="feature-card">
              <div className="feature-icon" aria-hidden="true">✦</div>
              <h3>Optional AI cleanup</h3>
              <p>
                Turn on punctuation and cleanup when you want it. The embedded
                model runs locally too—no server or separate app required.
              </p>
            </article>

            <article className="feature-card feature-card-wide history-card">
              <div>
                <div className="feature-icon" aria-hidden="true">↺</div>
                <h3>A useful memory, kept locally</h3>
                <p>
                  Search past dictations, copy an earlier thought, and see your
                  writing stats. History stays on this Mac and can be turned off.
                </p>
              </div>
              <div className="history-preview" aria-hidden="true">
                <div>
                  <strong>2,814</strong>
                  <span>words dictated</span>
                </div>
                <p>“The campaign brief is ready for…”</p>
                <p>“Can you send the revised deck…”</p>
              </div>
            </article>
          </div>
        </section>

        <section className="privacy-section" id="privacy">
          <div className="privacy-copy">
            <p className="eyebrow eyebrow-light">Private by design</p>
            <h2>Your voice should stay yours.</h2>
            <p>
              Rhino&apos;s transcription and optional cleanup models run on your
              Mac. There is no remote speech engine, no analytics, and no cloud
              account holding your words.
            </p>
            <p className="privacy-emphasis">
              Turn off Wi-Fi and dictation keeps working.
            </p>
          </div>
          <div className="privacy-ledger">
            <div>
              <span className="ledger-icon" aria-hidden="true">✓</span>
              <p><strong>Audio</strong><small>Processed on-device</small></p>
              <span className="ledger-status">Stays local</span>
            </div>
            <div>
              <span className="ledger-icon" aria-hidden="true">✓</span>
              <p><strong>Transcripts</strong><small>Stored only on your Mac</small></p>
              <span className="ledger-status">Stays local</span>
            </div>
            <div>
              <span className="ledger-icon" aria-hidden="true">✓</span>
              <p><strong>AI cleanup</strong><small>Embedded local model</small></p>
              <span className="ledger-status">Stays local</span>
            </div>
            <div className="ledger-note">
              The only network connections are update checks and model
              downloads you start yourself.
            </div>
          </div>
        </section>

        <section className="section how-section" id="how-it-works">
          <div className="section-heading centered">
            <p className="eyebrow">Up and running in minutes</p>
            <h2>Download. Talk. Done.</h2>
          </div>
          <ol className="steps">
            <li>
              <span>1</span>
              <h3>Download Rhino</h3>
              <p>Open the DMG and drag Rhino into your Applications folder.</p>
            </li>
            <li>
              <span>2</span>
              <h3>Choose your local model</h3>
              <p>
                Grant microphone and typing access, then download a speech
                model once.
              </p>
            </li>
            <li>
              <span>3</span>
              <h3>Hold Fn and speak</h3>
              <p>
                Release to put the finished text into the app you are already
                using.
              </p>
            </li>
          </ol>
        </section>

        <section className="section faq-section" id="questions">
          <div className="section-heading">
            <p className="eyebrow">Questions</p>
            <h2>Good things to know.</h2>
          </div>
          <div className="faq-list">
            <details>
              <summary>Does my audio or text ever leave my Mac?</summary>
              <p>
                No. Dictation and optional AI cleanup run locally. Rhino only
                connects for signed update checks and model downloads you
                explicitly start.
              </p>
            </details>
            <details>
              <summary>What Mac do I need?</summary>
              <p>
                Rhino currently requires an Apple silicon Mac running macOS 14
                or later.
              </p>
            </details>
            <details>
              <summary>Why is there a model download?</summary>
              <p>
                That speech model is what lets Rhino transcribe without sending
                recordings to a server. Download it once and it stays on your Mac.
              </p>
            </details>
            <details>
              <summary>Can I dictate without holding a key?</summary>
              <p>
                Yes. Double-press your shortcut to lock hands-free recording on,
                then press it again when you are finished.
              </p>
            </details>
          </div>
        </section>

        <section className="final-cta">
          <img src="/rhino-icon.png" alt="" width="78" height="78" />
          <p className="eyebrow">Private dictation for Mac</p>
          <h2>Stop typing every thought.</h2>
          <p>Hold a key. Say what you mean. Let Rhino handle the rest.</p>
          <DownloadButton />
          <span>Version 0.1.2 · macOS 14+ · Apple silicon</span>
        </section>
      </main>

      <footer>
        <a className="brand footer-brand" href="#top">
          <img src="/rhino-icon.png" alt="" width="34" height="34" />
          <span>Rhino</span>
        </a>
        <p>Private dictation that lives on your Mac.</p>
        <div>
          <a href={releasesUrl}>Release notes</a>
          <a href="#privacy">Privacy</a>
          <span>© 2026 Rhino</span>
        </div>
      </footer>
    </>
  );
}
