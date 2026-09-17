import type { Metadata } from "next";
import { BuyForm, SiteFooter, SiteHeader } from "../../_components/site-chrome";

type Pick = {
  name: string;
  bestFor: string;
  price: string;
  where: string;
  body: string[];
  url?: string;
};

const checked = "September 2026";

const picks: Pick[] = [
  {
    name: "superwhisper",
    bestFor: "the best free way to stop using the cloud",
    price: "Free tier; Pro around $8.49/month, with a lifetime option",
    where: "On your Mac, with local models selected",
    body: [
      "If you are leaving Wispr Flow because you do not want your voice on a server, superwhisper solves that today, for nothing. It runs Whisper models locally on Apple silicon, works offline, and its free tier is genuinely usable rather than a three-day teaser.",
      "The paid tier adds optional cloud models from OpenAI, Anthropic and Google, plus modes, custom prompts and per-app behaviour. That configurability is the appeal — and, if your bar is that the app should have no cloud pathway at all, also the caveat.",
    ],
    url: "https://superwhisper.com/",
  },
  {
    name: "VoiceInk",
    bestFor: "people who want to read the source",
    price: "Lifetime tiers from $29; free if you build it yourself",
    where: "On your Mac",
    body: [
      "Open source under GPLv3, built on whisper.cpp, and priced as a one-time licence rather than a subscription. If you have Xcode and the patience to build from source you can run it for free forever, trading away notarized downloads and auto-updates.",
      "Its Power Mode — per-app dictation settings, so your editor and your email client behave differently — is a genuinely good idea that most of the field has not copied. Cloud AI enhancement exists but is opt-in.",
    ],
    url: "https://tryvoiceink.com/",
  },
  {
    name: "Rhino",
    bestFor: "one payment, no cloud pathway, no decisions",
    price: "$20 once, with a 30-day money-back guarantee",
    where: "On your Mac, always — there is no other option in the app",
    body: [
      "This is mine, so discount it accordingly. Rhino is the opinionated version of the local-dictation idea: hold Fn, talk, release, and cleaned-up text lands where your cursor was. Speech recognition and the AI cleanup pass both run on your Mac, it works with Wi-Fi off, and there is no account, no telemetry and no cloud model to switch on.",
      "It is deliberately small. No modes to configure, no per-app profiles, no free tier. What it does have is defaults I would have told you to pick anyway: automatic verbatim pass-through when you dictate into Claude, ChatGPT or a terminal, a guard that copies very long recordings to the clipboard instead of pasting them somewhere unexpected, and a custom dictionary that boosts recognition of the names you repeat all day.",
      "Apple silicon and macOS 14 or later only. No Windows, no iPhone. If you need those, one of the others on this list is your answer.",
    ],
    url: "/",
  },
  {
    name: "Apple Dictation",
    bestFor: "finding out whether you need to pay anyone",
    price: "Free, built into macOS",
    where: "On your Mac, on Apple silicon with on-device dictation enabled",
    body: [
      "Before you buy anything, turn this on. It is already installed, it runs on-device, and on an Intel Mac it is the only local option on this list that runs at all.",
      "Its limit is not accuracy, it is literalness: it writes down what you said, including the ums, the false starts and the punctuation you have to speak aloud. If you speak in clean finished sentences, that is fine and you are done. If you think out loud, that is exactly the editing work a cleanup pass exists to remove.",
    ],
  },
  {
    name: "Aqua Voice",
    bestFor: "staying in the cloud, but paying less",
    price: "Free tier of 1,000 words; Pro $8/month billed annually",
    where: "In their cloud",
    body: [
      "If the thing you disliked about Wispr Flow was the price rather than the architecture, Aqua Voice is the obvious swap: roughly half the cost, comparable polish, and it runs on Windows and Intel Macs as well as Apple silicon.",
      "It is still a cloud service, so the trade you are making is money, not privacy. Worth being clear-eyed about which of the two actually bothered you.",
    ],
    url: "https://aquavoice.com/",
  },
  {
    name: "Typeless",
    bestFor: "a generous free tier across every device",
    price: "Free tier of 8,000 words/week; Pro $12/month billed annually",
    where: "In their cloud",
    body: [
      "The free allowance is the headline — 8,000 words a week is real daily use, not a demo — and it covers Mac, Windows, iPhone and Android.",
      "Same caveat as Aqua Voice: your audio is processed on their servers. It is a good cloud option, not an escape from the cloud.",
    ],
    url: "https://typeless.com/",
  },
  {
    name: "MacWhisper",
    bestFor: "people who wanted file transcription all along",
    price: "Free tier; Pro is a one-time licence, around €59 on Gumroad",
    where: "On your Mac",
    body: [
      "Included because a surprising number of people searching for a dictation app actually need this one. MacWhisper turns recordings you already have — interviews, meetings, video, YouTube URLs — into transcripts, with speaker labels, subtitle exports and batch processing.",
      "It includes system-wide dictation on the Gumroad version, so if you buy it for transcription you may not need a separate dictation app at all. But dictation is not what it is built around.",
    ],
    url: "https://goodsnooze.gumroad.com/l/macwhisper",
  },
];

const faq = [
  {
    question: "Why would I leave Wispr Flow?",
    answer:
      "Two reasons come up. The first is the subscription: $15 a month, or $12 billed annually, for a feature that an Apple silicon Mac can now run by itself. The second is that dictation is processed on Wispr Flow's servers, which matters if the things you dictate are client conversations, medical notes, legal drafts or unreleased work.",
  },
  {
    question: "Is there a free Wispr Flow alternative?",
    answer:
      "Yes, several. superwhisper's free tier runs Whisper models locally on your Mac at no cost, VoiceInk is open source and free if you build it from source, and Apple's built-in dictation is already installed and runs on-device on Apple silicon.",
  },
  {
    question: "Which Wispr Flow alternative is the most private?",
    answer:
      "The ones that never transmit audio: Apple Dictation with on-device dictation enabled, superwhisper and VoiceInk with local models selected, and Rhino, which has no cloud pathway in the app at all. Aqua Voice and Typeless are cloud services, so they are cheaper alternatives rather than more private ones.",
  },
  {
    question: "Do any of these work offline?",
    answer:
      "Apple Dictation, superwhisper, VoiceInk, MacWhisper and Rhino all transcribe on your Mac, so they keep working with the network off once their models are downloaded. Wispr Flow, Aqua Voice and Typeless need a connection.",
  },
  {
    question: "Is a one-time purchase actually cheaper?",
    answer:
      "For anything you use for more than a few months, yes, dramatically. A year of Wispr Flow Pro at the annual rate is $144. Rhino is $20 once; VoiceInk starts at $29 once; MacWhisper Pro is around €59 once. The subscription buys you cross-platform support and a funded team's roadmap, which is a real thing to want — it is just worth naming what you are paying for.",
  },
];

const jsonLd = [
  {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Rhino", item: "https://rhinovoice.app/" },
      {
        "@type": "ListItem",
        position: 2,
        name: "Wispr Flow alternatives",
        item: "https://rhinovoice.app/alternatives/wispr-flow",
      },
    ],
  },
  {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: "Wispr Flow alternatives (2026)",
    itemListElement: picks.map((pick, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: pick.name,
      description: pick.bestFor,
    })),
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

export const metadata: Metadata = {
  title: "Wispr Flow Alternatives (2026): 7 Honest Picks From a Competitor",
  description:
    "Leaving Wispr Flow over the $15/month bill, or over the cloud? Those are different problems with different answers. Seven alternatives compared honestly by a competitor.",
  alternates: { canonical: "https://rhinovoice.app/alternatives/wispr-flow" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/alternatives/wispr-flow",
    title: "Wispr Flow Alternatives (2026): 7 Honest Picks From a Competitor",
    description:
      "Free local options, cheaper cloud options, and the one I built. Compared honestly.",
  },
};

export default function Page() {
  return (
    <div className="doc-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <SiteHeader />

      <main className="doc" id="main">
        <nav className="breadcrumb" aria-label="Breadcrumb">
          <a href="/">Rhino</a>
          <span aria-hidden="true">/</span>
          <span>Wispr Flow alternatives</span>
        </nav>

        <h1>Wispr Flow alternatives (2026): 7 honest picks from a competitor</h1>
        <p className="dek">
          I build one of these, so read this with the appropriate suspicion. I have
          still tried to write the page I wanted when I was shopping.
        </p>

        <aside className="answer-box">
          <h2>The short answer</h2>
          <p>
            First work out which thing bothered you. If it is the $15 monthly bill,
            Aqua Voice and Typeless do the same cloud job for less, and a one-time
            purchase like VoiceInk or Rhino ends the bill entirely. If it is that your
            voice is processed on someone&apos;s server, you want an app that
            transcribes on your Mac: Apple Dictation, superwhisper, VoiceInk or Rhino.
          </p>
          <ul>
            <li>
              <strong>Best free local pick:</strong> superwhisper
            </li>
            <li>
              <strong>Best open-source pick:</strong> VoiceInk
            </li>
            <li>
              <strong>Best one-time purchase with no cloud pathway:</strong> Rhino (mine)
            </li>
            <li>
              <strong>Best cheaper cloud pick:</strong> Aqua Voice
            </li>
          </ul>
        </aside>

        <section>
          <h2>First: which problem are you actually solving?</h2>
          <p>
            Wispr Flow is a good app. People leave it for two quite different reasons,
            and the reason determines the answer.
          </p>
          <p>
            <strong>The bill.</strong> $15 a month, or $12 billed annually, is $144 a
            year for something your Mac has the hardware to do unaided. If that is your
            complaint, a cheaper subscription or a one-time purchase both fix it.
          </p>
          <p>
            <strong>The architecture.</strong> Wispr Flow processes your dictation on
            its servers. The company is SOC 2 Type II and ISO 27001 certified and offers
            a HIPAA-ready plan with a signed BAA, which is a serious compliance posture —
            but the audio still travels. If what you dictate is client conversations,
            case notes, patient notes or unreleased work, no certification changes the
            fact that a copy left your machine. That complaint is only fixed by an app
            that transcribes locally.
          </p>
          <p>
            Sort yourself into one of those two camps before reading on, because half
            this list is irrelevant to each of them.
          </p>
        </section>

        {picks.map((pick, index) => (
          <section key={pick.name} className="pick">
            <h2>
              {index + 1}. {pick.name}
              {pick.name === "Rhino" ? <span className="mine-badge">mine</span> : null}
            </h2>
            <dl className="pick-meta">
              <div>
                <dt>Best for</dt>
                <dd>{pick.bestFor}</dd>
              </div>
              <div>
                <dt>Price</dt>
                <dd>{pick.price}</dd>
              </div>
              <div>
                <dt>Where your speech is processed</dt>
                <dd>{pick.where}</dd>
              </div>
            </dl>
            {pick.body.map((paragraph) => (
              <p key={paragraph.slice(0, 40)}>{paragraph}</p>
            ))}
            {pick.url ? (
              <p>
                <a
                  className="inline-link"
                  href={pick.url}
                  {...(pick.url.startsWith("http")
                    ? { target: "_blank", rel: "noopener noreferrer" }
                    : {})}
                >
                  {pick.name === "Rhino" ? "See what Rhino does" : `Visit ${pick.name}`}
                </a>
              </p>
            ) : null}
          </section>
        ))}

        <section>
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

        <section className="doc-cta">
          <h2>Try Rhino</h2>
          <p>
            $20 once, no subscription and no account. If it does not earn its keep,
            email me inside 30 days and I will refund you.
          </p>
          <BuyForm />
        </section>

        <p className="checked-note">
          Pricing and capabilities for every app on this list checked {checked}. This
          field moves fast — verify current details on each site before you buy.
        </p>

        <nav className="more-links" aria-label="More comparisons">
          <h2>Head-to-head comparisons</h2>
          <ul>
            <li><a href="/vs/wispr-flow">Rhino vs Wispr Flow</a></li>
            <li><a href="/vs/superwhisper">Rhino vs superwhisper</a></li>
            <li><a href="/vs/macwhisper">Rhino vs MacWhisper</a></li>
            <li><a href="/vs/apple-dictation">Rhino vs Apple Dictation</a></li>
          </ul>
        </nav>
      </main>

      <SiteFooter />
    </div>
  );
}
