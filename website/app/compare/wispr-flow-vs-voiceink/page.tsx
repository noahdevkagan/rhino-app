import type { Metadata } from "next";
import { HeadToHeadPage, type HeadToHeadContent } from "../../_components/head-to-head-page";

const content: HeadToHeadContent = {
  slug: "/compare/wispr-flow-vs-voiceink",
  a: "Wispr Flow",
  b: "VoiceInk",
  headline: "Wispr Flow vs VoiceInk (2026): cloud subscription vs local, pay once",
  dek: "Full disclosure: I make Rhino Voice, which competes with both. I don't make either of these. This is the cleanest split in Mac dictation: one app in the cloud on a subscription, one on your Mac for a one-time price. Here's the honest comparison and where Rhino fits.",
  shortAnswer:
    "Wispr Flow processes your speech in the cloud, runs on Mac, Windows, iPhone and Android, and costs $12 a month billed yearly or $15 monthly after a 2,000-word weekly free plan. VoiceInk transcribes on your Mac with local models, is open source, and costs $25 once for one Mac, with a free build-it-yourself route. Flow is more polished and works everywhere; VoiceInk is cheaper and keeps transcription local.",
  pickA:
    "you dictate on Windows or your phone too, want the most polished experience, or need a vendor with compliance paperwork.",
  pickB:
    "you only dictate on an Apple silicon Mac, want to pay once, and like that the code is open.",
  rows: [
    { label: "Price", a: "$12/month billed yearly, $15 monthly", b: "$25 once (1 Mac), $39 (2 Macs), $49 (3 Macs)" },
    { label: "Free option", a: "2,000 words a week on desktop", b: "Free trial, or build it yourself from the open source code" },
    { label: "Three-year cost", a: "$432 yearly, $540 monthly", b: "$25 for one Mac" },
    { label: "Refund", a: "Not stated on the pricing page", b: "14 days" },
    { label: "Where your speech is processed", a: "On Wispr's servers", b: "On your Mac (local Parakeet and Whisper models)" },
    { label: "Optional cloud", a: "Cloud only", b: "AI enhancement can use cloud models if you turn it on" },
    { label: "Works offline", a: "No", b: "Yes, for local transcription" },
    { label: "Platforms", a: "Mac, Windows, iPhone, Android", b: "Apple silicon Mac (macOS 14.4+), and a newer iOS app" },
    { label: "Open source", a: "No", b: "Yes, GPLv3" },
  ],
  sections: [
    {
      heading: "Where Wispr Flow wins",
      paragraphs: [
        "Everywhere you type. Mac, Windows, iPhone and Android with one account. VoiceInk is a Mac app first, with a newer iOS app.",
        "Less to set up. Flow signs you in and works. VoiceInk asks you to pick and download a local model, and its settings (Power Mode, per-app behavior, AI enhancement) reward people who like to tinker.",
        "A company behind it. Flow has team plans, admin controls and enterprise compliance. VoiceInk is a small independent project.",
      ],
    },
    {
      heading: "Where VoiceInk wins",
      paragraphs: [
        "Price. $25 once for one Mac covers about two months of Flow Pro. Over three years it's $25 against at least $432.",
        "Local transcription. Your speech is turned into text on your Mac, and it works with Wi-Fi off. If you turn on AI enhancement with a cloud provider, that text does leave the machine, so check that setting.",
        "Open source. The code is public under GPLv3, so you can read what it does, or build it yourself for free if you're comfortable in Xcode.",
      ],
    },
  ],
  rhinoFit: [
    "If you're leaning VoiceInk because you want local and pay-once, Rhino Voice is the other app built for exactly that, with one difference: there's no cloud option in the app at all. Transcription and cleanup both run on your Mac, so there's no setting that can send your words anywhere.",
    "Rhino is free for 2,000 words a week (unlimited your first week), and $20 once for unlimited on all your Macs. It's deliberately simple: hold Fn, talk, release. Fewer knobs than VoiceInk, which is the point, or the downside, depending on you.",
    "Like VoiceInk it needs an Apple silicon Mac with macOS 14 or newer, and there's no Windows or phone app. If you need those, Flow is the answer.",
  ],
  faq: [
    {
      question: "Is VoiceInk really a one-time purchase?",
      answer:
        "Yes. VoiceInk's site lists lifetime licenses: $25 for one Mac, $39 for two, $49 for three, with lifetime updates and a 14-day refund. Some third-party pages quote older or newer prices, so check tryvoiceink.com.",
    },
    {
      question: "Does VoiceInk work offline?",
      answer:
        "Yes, transcription runs on your Mac with local models. Optional AI enhancement can use cloud providers if you enable it.",
    },
    {
      question: "Is VoiceInk free?",
      answer:
        "The source code is free under GPLv3 and you can build it yourself. The ready-to-run app with auto-updates is a paid one-time license with a free trial.",
    },
    {
      question: "What's the cheapest local alternative to Wispr Flow?",
      answer:
        "Rhino Voice is free for 2,000 words a week and $20 once for unlimited, entirely on-device. VoiceInk is $25 once. Apple Dictation is free and built into macOS, without AI cleanup.",
    },
  ],
  sources: [
    "Wispr Flow pricing page and pricing FAQ (wisprflow.ai/pricing), checked October 20, 2026",
    "VoiceInk homepage pricing and FAQ (tryvoiceink.com), checked October 20, 2026",
  ],
  checked: "October 2026",
};

export const metadata: Metadata = {
  title: "Wispr Flow vs VoiceInk (2026): Cloud Subscription vs Local",
  description:
    "Wispr Flow vs VoiceInk: $12-15/month in the cloud vs $25 once on your Mac, open source. An honest comparison, plus where Rhino fits.",
  alternates: { canonical: "https://rhinovoice.app/compare/wispr-flow-vs-voiceink" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/compare/wispr-flow-vs-voiceink",
    title: "Wispr Flow vs VoiceInk (2026)",
    description: "Cloud subscription vs local, pay once. The honest comparison.",
  },
};

export default function Page() {
  return <HeadToHeadPage content={content} />;
}
