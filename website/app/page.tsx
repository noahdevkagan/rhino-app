import { BuyForm, RhinoMark, SiteFooter, SiteHeader } from "./_components/site-chrome";

const steps = [
  {
    title: "Hold Fn",
    body: "Anywhere on your Mac — an email, a doc, Slack, a terminal, a prompt box. Rhino does not need to be the front-most app.",
  },
  {
    title: "Talk normally",
    body: "Ramble. Change your mind mid-sentence. Say the name of that client you can never spell. Rhino is built for how people actually speak.",
  },
  {
    title: "Release",
    body: "Cleaned-up text lands at your cursor: punctuated, capitalised, filler words gone. No window to switch to, no paste step.",
  },
];

const features = [
  {
    title: "Nothing is transmitted",
    body: "Speech recognition and the AI cleanup pass both run on your Mac. There is no cloud model to switch on, no account, and no telemetry. Turn off Wi-Fi and dictation still works.",
  },
  {
    title: "It knows your vocabulary",
    body: "Teach Rhino the names, products and jargon you say fifty times a day. The custom dictionary both replaces text and boosts recognition, so they stop coming back wrong.",
  },
  {
    title: "Verbatim where it matters",
    body: "Dictate into Claude, ChatGPT or a terminal and Rhino skips its cleanup pass automatically, so an instruction meant for the assistant arrives exactly as you said it.",
  },
  {
    title: "No surprise wall of text",
    body: "Recordings of five minutes or more are copied to your clipboard with a note instead of pasting themselves into whatever window happened to be focused.",
  },
  {
    title: "History you control",
    body: "Past dictations are searchable on your Mac, and you can re-run a recording through a different local model. Or switch history off entirely and keep nothing.",
  },
  {
    title: "One payment",
    body: "$20, once. Every feature, unlimited dictation, unlimited Macs, lifetime updates. No seat count, no word cap, no renewal.",
  },
];

const comparisonRows = [
  {
    label: "Where your voice is processed",
    rhino: "On your Mac",
    cloud: "On their servers",
    apple: "On your Mac",
  },
  {
    label: "Cost",
    rhino: "$20 once",
    cloud: "$8–$15 per month",
    apple: "Free",
  },
  {
    label: "Works with Wi-Fi off",
    rhino: "Yes",
    cloud: "No",
    apple: "Yes",
  },
  {
    label: "Removes filler words and false starts",
    rhino: "Yes",
    cloud: "Yes",
    apple: "No",
  },
  {
    label: "Account required",
    rhino: "No",
    cloud: "Yes",
    apple: "No",
  },
];

const faq = [
  {
    question: "Does my voice or my text leave my Mac?",
    answer:
      "No. Audio, transcripts, history and the AI cleanup pass all stay on your Mac. Rhino only reaches the network to check for signed app updates and to download speech models you explicitly ask for.",
  },
  {
    question: "Does Rhino work offline?",
    answer:
      "Yes. Once you have downloaded a speech model, dictation and cleanup both work with the network off — on a plane, on hotel Wi-Fi you do not trust, or with the machine air-gapped.",
  },
  {
    question: "What are the system requirements?",
    answer:
      "An Apple silicon Mac running macOS 14 or later. Intel Macs are not supported, because the on-device speech and cleanup models need Apple silicon to run fast enough to be worth using.",
  },
  {
    question: "Which apps does Rhino work with?",
    answer:
      "Any Mac app that accepts text. Rhino inserts at your cursor wherever it happens to be — mail clients, browsers, editors, Slack, terminals. It needs Microphone and Accessibility permissions to do that.",
  },
  {
    question: "How is this different from Wispr Flow?",
    answer:
      "Wispr Flow processes your speech in its cloud on a $15/month subscription and runs on Mac, Windows and mobile. Rhino Voice processes everything on your own Mac, works offline, costs $20 once, and is macOS-only.",
  },
  {
    question: "How is this different from the dictation built into macOS?",
    answer:
      "Apple's dictation also runs on-device, so it solves the privacy question too. What it does not do is clean up how people speak — it transcribes you literally, ums and false starts included. Rhino Voice runs a local AI pass that turns what you said into the sentence you meant.",
  },
  {
    question: "Is there a free trial?",
    answer:
      "There is a 30-day money-back guarantee instead. Buy it, use it properly, and if it has not earned its keep, email me and I will refund you.",
  },
  {
    question: "Can I delete my dictation history?",
    answer:
      "Yes. History lives on your Mac. You can delete individual recordings, clear all of it, set a retention limit, or turn history off so nothing is stored in the first place.",
  },
];

const jsonLd = [
  {
    "@context": "https://schema.org",
    "@type": "SoftwareApplication",
    name: "Rhino Voice",
    operatingSystem: "macOS 14 or later, Apple silicon",
    applicationCategory: "BusinessApplication",
    description:
      "Rhino Voice is a private dictation app for Mac. Hold Fn, speak, and release to insert cleaned-up text into any app. Speech recognition and AI cleanup run entirely on your Mac, with no account and no cloud service.",
    url: "https://rhinovoice.app/",
    author: { "@type": "Person", name: "Noah Kagan" },
    offers: {
      "@type": "Offer",
      price: "20.00",
      priceCurrency: "USD",
      availability: "https://schema.org/InStock",
    },
  },
  {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: faq.map((entry) => ({
      "@type": "Question",
      name: entry.question,
      acceptedAnswer: { "@type": "Answer", text: entry.answer },
    })),
  },
];

export default function Home() {
  return (
    <div className="home-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <SiteHeader />

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

      <div className="below-fold">
        <section className="band">
          <h2>Three keys, one sentence</h2>
          <ol className="steps">
            {steps.map((step) => (
              <li key={step.title}>
                <h3>{step.title}</h3>
                <p>{step.body}</p>
              </li>
            ))}
          </ol>
        </section>

        <section className="band">
          <h2>What you get for $20</h2>
          <div className="feature-grid">
            {features.map((feature) => (
              <div key={feature.title}>
                <h3>{feature.title}</h3>
                <p>{feature.body}</p>
              </div>
            ))}
          </div>
        </section>

        <section className="band">
          <h2>How Rhino Voice compares</h2>
          <p className="band-intro">
            Most dictation apps send your audio to a server and bill you monthly.
            Apple&apos;s built-in dictation keeps it local but transcribes you
            literally. Rhino is the third option.
          </p>
          <div className="table-wrap">
            <table className="compare-table">
              <caption>Rhino Voice vs cloud dictation apps vs Apple Dictation</caption>
              <thead>
                <tr>
                  <th scope="col">&nbsp;</th>
                  <th scope="col">Rhino Voice</th>
                  <th scope="col">Cloud apps</th>
                  <th scope="col">Apple Dictation</th>
                </tr>
              </thead>
              <tbody>
                {comparisonRows.map((row) => (
                  <tr key={row.label}>
                    <th scope="row">{row.label}</th>
                    <td>{row.rhino}</td>
                    <td>{row.cloud}</td>
                    <td>{row.apple}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <ul className="more-links-inline">
            <li><a href="/vs/wispr-flow">Rhino Voice vs Wispr Flow</a></li>
            <li><a href="/vs/superwhisper">Rhino Voice vs superwhisper</a></li>
            <li><a href="/vs/macwhisper">Rhino Voice vs MacWhisper</a></li>
            <li><a href="/vs/apple-dictation">Rhino Voice vs Apple Dictation</a></li>
            <li><a href="/alternatives/wispr-flow">Wispr Flow alternatives</a></li>
          </ul>
        </section>

        <section className="band">
          <h2>Questions</h2>
          <dl className="faq">
            {faq.map((entry) => (
              <div key={entry.question}>
                <dt>{entry.question}</dt>
                <dd>{entry.answer}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section className="band closing-cta">
          <h2>Stop typing what you could have said.</h2>
          <p>$20 once. No subscription, no account, nothing transmitted.</p>
          <BuyForm />
          <p className="purchase-note">30-day money-back guarantee.</p>
        </section>
      </div>

      <SiteFooter />
    </div>
  );
}
