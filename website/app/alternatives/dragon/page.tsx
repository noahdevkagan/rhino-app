import type { Metadata } from "next";
import { RankedPage, type RankedPageContent } from "../../_components/ranked-page";
import { tools } from "../../_components/competitors";
import { rhinoPrice } from "../../_components/site-chrome";

const content: RankedPageContent = {
  slug: "/alternatives/dragon",
  crumb: "Dragon alternatives for Mac",
  h1: "The 6 best Dragon alternatives for Mac in 2026",
  quickAnswer: (
    <>
      <p>
        Dragon did two jobs, and you replace them separately. For turning speech into text,
        Rhino Voice is the best Dragon alternative for Mac: ${rhinoPrice} once, it runs on
        your Mac the way Dragon did, and it learns your names and jargon. For operating
        your Mac by voice, use macOS Voice Control, which is free and already installed.
      </p>
      <ul>
        <li>
          <strong>Pick superwhisper</strong> if you want to try modern dictation for free.
        </li>
        <li>
          <strong>Pick MacWhisper</strong> if you used Dragon to transcribe recordings.
        </li>
        <li>
          <strong>Pick Dragon on Windows</strong> only if you truly need Dragon itself.
        </li>
      </ul>
    </>
  ),
  intro: (
    <>
      <p>
        Dragon for Mac is not coming back. Nuance discontinued it on 22 October 2018, the
        last version was 6.0.8, and it broke with macOS Catalina in 2019. Any Mac bought in
        the last six years cannot run it. The good news: speech recognition got much better
        and much cheaper while nobody was selling it to Mac users.
      </p>
      <p>
        If you came to Dragon because of RSI, a mobility impairment or an injury, set up
        Voice Control first. The dictation apps on this list assume you can still reach a
        keyboard. I make Rhino, so it&apos;s listed first. Each tool below says what it does
        better than us.
      </p>
    </>
  ),
  rankedFor:
    "a former Dragon user on an Apple silicon Mac who mostly needs speech turned into text",
  entries: [
    {
      tool: tools.rhino,
      badge: "Best value",
      bestFor: "the Dragon deal you remember: pay once, runs locally",
      review: [
        "Rhino works the way Dragon did: you pay once, you own it, and it runs on your machine. Hold Fn, talk, release, and cleaned-up text lands wherever your cursor was, in Mail, Pages, a browser or a terminal.",
        "The part that maps to Dragon habits is the vocabulary. Teach it the client names, drug names and case numbers you say fifty times a day and it fixes the spelling and boosts recognition. Its cleanup pass also removes the ums and false starts, which Dragon never did. Pick it if dictation is the half of Dragon you miss.",
      ],
      shot: {
        src: "/img/rhino-dictionary.jpg",
        alt: "The Rhino Voice dictionary screen with custom words like AppSumo and Noah Kagan",
        caption: "Rhino's dictionary: your names and jargon, stored only on your Mac.",
        width: 1200,
        height: 705,
      },
    },
    {
      tool: tools.voiceControl,
      bestFor: "the half of Dragon that drove the computer",
      review: [
        "If you miss saying \"click Send\", \"open Mail\" or \"scratch that\", this is the honest answer, and it is already on your Mac. Apple built it into macOS in 2019, the year after Dragon left. It is the only option here that replaces hands-free operation of the whole computer, and it runs fine next to a dictation app.",
      ],
    },
    {
      tool: tools.superwhisper,
      bestFor: "trying modern dictation for free",
      review: [
        "Dragon users tend to expect disappointment because the free dictation they last tried was years ago. superwhisper is the cheapest way to check whether that is still true. Its free tier runs local models, works offline, and needs no voice training first.",
      ],
    },
    {
      tool: tools.voiceInk,
      bestFor: "open source you can keep forever",
      review: [
        "If part of leaving Dragon was resenting software you could not inspect or keep, VoiceInk is the most thorough answer: open source, one-time license, and free if you build it yourself. Its per-app Power Mode is the closest thing here to Dragon's per-context profiles.",
      ],
    },
    {
      tool: tools.macWhisper,
      bestFor: "transcribing recordings, the way Dragon could",
      review: [
        "Dragon could turn an audio file into a transcript, and that is a different job from live dictation. If you dictated into a recorder or transcribed interviews afterward, MacWhisper is the specialist, and it is far better at it than Dragon was.",
      ],
    },
    {
      tool: tools.wisprFlow,
      bestFor: "polish across Mac, Windows and mobile",
      review: [
        "The most finished product in the category, and the one that follows you across machines. The trade is one Dragon never asked of you: your speech is processed on someone else's servers. It has SOC 2 Type II, ISO 27001 and a HIPAA-ready plan, which matters if you need that box ticked.",
      ],
    },
  ],
  costCaption: "What you pay over one and three years",
  costTools: [
    tools.rhino,
    tools.voiceControl,
    tools.superwhisper,
    tools.voiceInk,
    tools.macWhisper,
    tools.wisprFlow,
    tools.dragonWindows,
  ],
  afterCards: (
    <section>
      <h2>When you still need Dragon itself</h2>
      <p>
        Dragon is not dead, it just left the Mac. Dragon Professional v16 is still sold for
        Windows, around $699 once. If your work depends on Dragon macros, a vocabulary you
        spent years training, or a workflow your firm standardized on, run the real thing
        on Windows. On a Mac that means Parallels or a separate PC, and on Apple silicon it
        means Windows on ARM, which is a project rather than an afternoon. Worth it for a
        few people. A bad idea for everyone else.
      </p>
    </section>
  ),
  notRanked: [
    {
      tool: tools.appleDictation,
      why: "Free and on-device, but it types you literally, ums and spoken punctuation included. Voice Control covers what most Dragon users want from Apple.",
    },
    {
      tool: tools.aquaVoice,
      why: "A cheaper cloud dictation app. Dragon ran on your own machine, and most people leaving it want to keep it that way.",
    },
  ],
  howWeChecked: (
    <p>
      Dragon&apos;s discontinuation dates and every price come from the vendors&apos; own
      sites, checked in September 2026, at the annual rate where one is offered. The
      ranking is for a former Dragon user on an Apple silicon Mac who mostly needs speech
      turned into text. Nobody paid to be on this list, and Rhino&apos;s price is read from
      the same code as the checkout button. Dragon still has an edge in specialized
      medical and legal vocabulary after decades of tuning. A custom dictionary closes a
      lot of that gap, not all of it.
    </p>
  ),
  howToSwitch: [
    "If you need hands-free control, turn on Voice Control under Accessibility in System Settings.",
    `Buy Rhino for $${rhinoPrice} and download it for your Mac.`,
    "Retype the terms that matter from your old Dragon vocabulary into Rhino's dictionary.",
    "Hold your trigger key, talk, and release.",
  ],
  faq: [
    {
      question: "What is the best Dragon alternative for Mac?",
      answer: `For dictation, Rhino Voice: $${rhinoPrice} once and it runs on your Mac. For controlling your Mac by voice, macOS Voice Control, which is free. For transcribing recordings, MacWhisper.`,
    },
    {
      question: "Is Dragon still available for Mac?",
      answer:
        "No. Nuance discontinued Dragon Professional Individual for Mac on 22 October 2018 and stopped updates the same day. The final release was 6.0.8. Microsoft bought Nuance in 2022 and no Mac version has shipped since. Dragon Professional v16 is Windows only.",
    },
    {
      question: "Can I still run my old copy of Dragon for Mac?",
      answer:
        "Not on a current Mac. Dragon for Mac 6 was supported only through macOS Mojave (10.14) and broke with Catalina (10.15) in 2019. Every Mac sold since ships with a macOS it cannot run on.",
    },
    {
      question: "What replaced Dragon's voice commands on the Mac?",
      answer:
        "macOS Voice Control, free and built in. It handles menu commands, clicking, correction phrases and moving around without a keyboard or mouse. The dictation apps on this list type; they do not drive the computer.",
    },
    {
      question: "Is anything as accurate as Dragon was?",
      answer:
        "For everyday dictation, yes. On Apple silicon, Whisper-family models generally match or beat where Dragon was when it left the Mac, with no training session. Dragon still leads in specialized medical and legal vocabulary.",
    },
    {
      question: "Can I bring my Dragon vocabulary across?",
      answer:
        "Not as a file. Nothing here imports Dragon's format. You can retype the terms that matter into a custom dictionary; Rhino Voice, superwhisper, VoiceInk and MacWhisper all have one.",
    },
  ],
};

export const metadata: Metadata = {
  title: "The 6 Best Dragon Alternatives for Mac in 2026 (Ranked, With Prices)",
  description:
    "Dragon for Mac was discontinued in 2018 and will not run on a current Mac. The 6 best replacements, ranked by a competitor, including the free one that covers voice commands.",
  alternates: { canonical: "https://rhinovoice.app/alternatives/dragon" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/alternatives/dragon",
    title: "The 6 best Dragon alternatives for Mac in 2026",
    description:
      "Discontinued in 2018, broken since Catalina. What replaces each half of it, ranked.",
  },
};

export default function Page() {
  return <RankedPage content={content} />;
}
