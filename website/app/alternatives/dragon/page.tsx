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
    name: "macOS Voice Control",
    bestFor: "the half of Dragon that drove the computer, not the typing",
    price: "Free, built into macOS",
    where: "On your Mac",
    body: [
      "If what you miss is saying \"scratch that\", \"click Send\", \"open Mail\" or moving a cursor without touching one, this is the honest answer and it is already installed. Apple built full voice control of the machine into macOS in 2019, the year after Dragon left: dictation plus command grammar plus a numbered-and-gridded overlay for clicking anything on screen. Turn it on in System Settings under Accessibility.",
      "It is not as fluent as Dragon was at its best, and the command vocabulary takes a week to feel natural. But it is the only option on this list that replaces Dragon's hands-free operation of the whole computer, and every dictation app below assumes you can still reach a keyboard. If you used Dragon because of RSI, a mobility impairment, or an injury, start here and treat the rest of this page as optional extras.",
    ],
    url: "https://support.apple.com/guide/mac-help/use-voice-control-mchlp2839/mac",
  },
  {
    name: "superwhisper",
    bestFor: "the cheapest way to find out whether modern dictation is good enough",
    price: "Free tier; Pro around $8.49/month, with a lifetime option",
    where: "On your Mac, with local models selected",
    body: [
      "Dragon refugees tend to arrive braced for disappointment, because the free dictation they last tried was in about 2015. The thing worth knowing is that the underlying speech recognition got dramatically better while nobody was selling it to you — Whisper-family models running on Apple silicon are, on ordinary dictation, at or past where Dragon was when it left the Mac, with no voice training session first.",
      "superwhisper is the cheapest way to verify that claim rather than take my word for it. The free tier runs local models on your Mac, works offline, and is a real app rather than a trial. If it convinces you, the paid tier adds modes, custom prompts and optional cloud models.",
    ],
    url: "https://superwhisper.com/",
  },
  {
    name: "Rhino Voice",
    bestFor: "one payment, no cloud pathway, nothing to configure",
    price: "$20 once, with a 30-day money-back guarantee",
    where: "On your Mac, always — there is no other option in the app",
    body: [
      "This one is mine, so weigh it accordingly. Rhino is the closest thing here to the Dragon deal you remember: you pay once, you own it, and the software runs on your own machine rather than renting you access to somebody's server. Hold Fn, talk, release, and cleaned-up text lands wherever the cursor was — in Mail, Pages, a browser box, a terminal.",
      "The part that maps directly onto Dragon habits is the vocabulary. Teach it the client names, drug names, case numbers and jargon you say fifty times a day and it both corrects the spelling and boosts recognition, so they stop coming back wrong. The cleanup pass also does what Dragon never did: it removes the ums and false starts and turns what you actually said into the sentence you meant.",
      "Two things it is not. It does not drive your Mac by voice — no menu commands, no clicking, no \"scratch that\" — so it does not replace Dragon for hands-free operation. And it needs an Apple silicon Mac on macOS 14 or later, which rules out the older Intel machine a lot of Dragon holdouts are still running.",
    ],
    url: "/",
  },
  {
    name: "VoiceInk",
    bestFor: "people who want to read the source and pay once",
    price: "Lifetime tiers from $29; free if you build it yourself",
    where: "On your Mac",
    body: [
      "Open source under GPLv3, built on whisper.cpp, sold as a one-time licence. If you left Dragon partly because you resented software you could not inspect or keep, this is the most thorough answer to that instinct: you can read every line, and if you have Xcode and patience you can build and run it for nothing, trading away notarized downloads and automatic updates.",
      "Its Power Mode gives per-app dictation settings, so your editor and your email client can behave differently — closer to Dragon's per-context profiles than anything else on this list.",
    ],
    url: "https://tryvoiceink.com/",
  },
  {
    name: "MacWhisper",
    bestFor: "transcribing recordings, not just live dictation",
    price: "Free tier; Pro is a one-time licence, around €59 on Gumroad",
    where: "On your Mac",
    body: [
      "Dragon could take a recorded audio file and turn it into a transcript, and that is a genuinely different job from live dictation. If that is the workflow you lost — dictating into a recorder on the move, or transcribing interviews and depositions afterwards — MacWhisper is the specialist and it is far better at it than Dragon ever was, with speaker labels, subtitle export and batch jobs on the Pro licence.",
      "It also does hold-a-key dictation on the Gumroad version, so for some people it covers both jobs in one purchase. It is not the focus of the app, but it is there.",
    ],
    url: "https://goodsnooze.gumroad.com/l/macwhisper",
  },
  {
    name: "Wispr Flow",
    bestFor: "people who want the most polished experience and do not mind the cloud",
    price: "$15/month, or $12/month billed annually",
    where: "On Wispr's servers",
    body: [
      "The most finished product in this category, and the one that will feel least like a downgrade from commercial software with a support department behind it. It runs on Mac, Windows and mobile, so if Dragon's absence stranded you across several machines this is the one list entry that follows you.",
      "The trade you are making is the one Dragon never asked of you: your speech is processed on someone else's servers. The company holds SOC 2 Type II and ISO 27001 certifications and offers a HIPAA-ready plan with a signed BAA, which matters if that is the box you need ticked. It still means a copy of your dictation leaves the machine, which for case notes, patient notes or privileged material is a different decision from the one you made when you bought Dragon in a box.",
    ],
    url: "https://wisprflow.ai/",
  },
  {
    name: "Dragon Professional v16, on Windows",
    bestFor: "people who genuinely need Dragon itself, not a replacement",
    price: "Around $699 one-time, Windows only",
    where: "On the Windows machine running it",
    body: [
      "Dragon is not dead, it just left the Mac. Dragon Professional v16 is still sold as a Windows licence, and if your work depends on Dragon-specific macros, a vocabulary you spent years training, or a workflow your firm has standardised on, the honest advice is to run the real thing on Windows rather than approximate it here.",
      "On a Mac that means Parallels or a separate PC, and on Apple silicon it means Windows on ARM, where audio input and Dragon's own requirements make this a project rather than an afternoon. Worth it for a small number of people, and a bad idea for everyone else.",
    ],
  },
];

const faq = [
  {
    question: "Is Dragon still available for Mac?",
    answer:
      "No. Nuance discontinued Dragon Professional Individual for Mac on 22 October 2018 and stopped shipping updates the same day. The final release was version 6.0.8. Nuance was acquired by Microsoft in 2022 and no Mac version has been released since. Dragon Professional v16 is Windows-only.",
  },
  {
    question: "Can I still run my old copy of Dragon for Mac?",
    answer:
      "Not on a current Mac. Dragon for Mac 6 was only ever supported through macOS Mojave (10.14), and it broke with Catalina (10.15) in 2019. Every Mac sold since then ships with a macOS it cannot run on, and there is no patch coming.",
  },
  {
    question: "What replaced Dragon's voice commands on the Mac?",
    answer:
      "macOS Voice Control, which is free and built into the system. It handles the part of Dragon that operated the computer — menu commands, clicking, correction phrases, navigating without a keyboard or mouse. The dictation apps on this list deliberately do not do that; they type, and you drive.",
  },
  {
    question: "Is anything as accurate as Dragon was?",
    answer:
      "For ordinary dictation, yes — on Apple silicon, Whisper-family models generally match or beat where Dragon was when it left the Mac, and they do it without asking you to read training passages first. Dragon still holds an edge in specialised professional vocabularies, particularly medical and legal, where it had decades of tuning that a general model does not replicate. A custom dictionary closes a lot but not all of that gap.",
  },
  {
    question: "Do these need an internet connection?",
    answer:
      "Voice Control, superwhisper with local models, VoiceInk, MacWhisper and Rhino Voice all run on your Mac and work with Wi-Fi off, once you have downloaded a speech model. Wispr Flow does not — it processes your speech on its servers and needs a connection.",
  },
  {
    question: "Can I bring my Dragon vocabulary across?",
    answer:
      "Not as a file. Dragon's trained vocabulary is in its own format and nothing here imports it. What you can do is retype the terms that matter into a custom dictionary — Rhino Voice, superwhisper, VoiceInk and MacWhisper all have one. It is an afternoon of work for a list most people find is shorter than they expected.",
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
        name: "Dragon alternatives for Mac",
        item: "https://rhinovoice.app/alternatives/dragon",
      },
    ],
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
  title: "Dragon Alternatives for Mac (2026): What to Use Now It Is Gone",
  description:
    "Dragon for Mac was discontinued in 2018 and will not run on a current Mac. Seven replacements compared honestly by a competitor — including the free one that covers voice commands.",
  alternates: { canonical: "https://rhinovoice.app/alternatives/dragon" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/alternatives/dragon",
    title: "Dragon Alternatives for Mac (2026): What to Use Now It Is Gone",
    description:
      "Discontinued in 2018, broken since Catalina. Here is what actually replaces each half of it.",
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
          <span>Dragon alternatives for Mac</span>
        </nav>

        <h1>Dragon alternatives for Mac (2026): what to use now it is gone</h1>
        <p className="dek">
          I build one of these, so read this with the appropriate suspicion. I have
          still tried to write the page I would have wanted the day I found out Dragon
          for Mac no longer existed.
        </p>

        <aside className="answer-box">
          <h2>The short answer</h2>
          <p>
            Dragon did two jobs and you have to replace them separately. If you used it
            to <strong>operate your Mac by voice</strong>, the replacement is macOS Voice
            Control, which is free and already installed. If you used it to{" "}
            <strong>turn speech into text</strong>, a modern local dictation app does that
            at least as well as Dragon did, for a fraction of the price.
          </p>
          <ul>
            <li>
              <strong>Best replacement for voice commands:</strong> macOS Voice Control
              (free)
            </li>
            <li>
              <strong>Best free way to try modern dictation:</strong> superwhisper
            </li>
            <li>
              <strong>Best one-time purchase, nothing transmitted:</strong> Rhino Voice
              (mine)
            </li>
            <li>
              <strong>Best for transcribing recordings:</strong> MacWhisper
            </li>
          </ul>
        </aside>

        <section>
          <h2>Dragon for Mac is not coming back</h2>
          <p>
            Nuance discontinued Dragon Professional Individual for Mac on 22 October 2018
            and stopped shipping updates the same day. The last release was 6.0.8, it was
            only ever supported through macOS Mojave, and it broke with Catalina the
            following year. Nuance was bought by Microsoft in 2022. Dragon itself
            continues as a Windows product and in healthcare, but there has been no Mac
            version for seven years and there is no indication there will be one.
          </p>
          <p>
            So this is not a question of waiting it out or finding a compatibility trick.
            If you are on any Mac bought in the last six years, Dragon will not run on it,
            and the question is only what to do instead.
          </p>
        </section>

        <section>
          <h2>Which half of Dragon do you actually need?</h2>
          <p>
            This matters more than any product on the list, because the two halves have
            completely different answers and most articles on this topic quietly only
            answer one of them.
          </p>
          <p>
            <strong>Operating the computer.</strong> Saying &quot;scratch that&quot;,
            &quot;click Send&quot;, &quot;go to sleep&quot;, correcting by voice, moving
            around the screen without a mouse. If you came to Dragon through RSI, a
            mobility impairment or an injury, this is the half you cannot do without — and
            none of the dictation apps below provide it. macOS Voice Control does, it is
            free, and you should set it up first.
          </p>
          <p>
            <strong>Turning speech into text.</strong> Drafting email, notes, reports and
            documents faster than you can type them. This is the half that got much better
            and much cheaper while Dragon was away, and it is what the rest of this list
            is about.
          </p>
          <p>
            Plenty of people need both. The good news is that the free half and the paid
            half do not conflict: Voice Control can drive the machine while a dictation app
            handles the words.
          </p>
        </section>

        {picks.map((pick, index) => (
          <section key={pick.name} className="pick">
            <h2>
              {index + 1}. {pick.name}
              {pick.name === "Rhino Voice" ? <span className="mine-badge">mine</span> : null}
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
                  {pick.name === "Rhino Voice"
                    ? "See what Rhino Voice does"
                    : `Visit ${pick.name}`}
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
          <h2>Try Rhino Voice</h2>
          <p>
            $20 once, no subscription and no account, and it runs on your Mac the way
            Dragon used to. If it does not earn its keep, email me inside 30 days and I
            will refund you.
          </p>
          <BuyForm />
        </section>

        <p className="checked-note">
          Dragon&apos;s discontinuation dates, and pricing and capabilities for every app
          on this list, checked {checked}. This field moves fast — verify current details
          on each site before you buy.
        </p>

        <nav className="more-links" aria-label="More comparisons">
          <h2>Head-to-head comparisons</h2>
          <ul>
            <li><a href="/vs/apple-dictation">Rhino Voice vs Apple Dictation</a></li>
            <li><a href="/vs/superwhisper">Rhino Voice vs superwhisper</a></li>
            <li><a href="/vs/macwhisper">Rhino Voice vs MacWhisper</a></li>
            <li><a href="/vs/wispr-flow">Rhino Voice vs Wispr Flow</a></li>
            <li><a href="/alternatives/wispr-flow">Wispr Flow alternatives</a></li>
          </ul>
        </nav>
      </main>

      <SiteFooter />
    </div>
  );
}
