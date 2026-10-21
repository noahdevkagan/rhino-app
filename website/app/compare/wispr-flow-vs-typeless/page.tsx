import type { Metadata } from "next";
import { HeadToHeadPage, type HeadToHeadContent } from "../../_components/head-to-head-page";

const content: HeadToHeadContent = {
  slug: "/compare/wispr-flow-vs-typeless",
  a: "Wispr Flow",
  b: "Typeless",
  headline: "Wispr Flow vs Typeless (2026): the same price, very different free plans",
  dek: "Full disclosure: I make Rhino Voice, which competes with both. I don't make either of these. They're the two cloud dictation apps people compare most, so here's an honest head-to-head from their own pricing pages, and where a local app fits.",
  shortAnswer:
    "Wispr Flow and Typeless both cost $12 a month billed yearly and both process your speech in the cloud. The differences are the free plan and monthly billing. Typeless gives free users far more words a week, but its monthly plan is $30 against Flow's $15. Flow is the more established app and adds a meeting notetaker. Typeless also runs on Linux.",
  pickA:
    "you pay month to month, want a meeting notetaker in the same app, or want the app most people in the category already use.",
  pickB:
    "you want to stay on a free plan, pay yearly anyway, or need dictation on Linux.",
  rows: [
    { label: "Free plan", a: "2,000 words a week on desktop, limited on mobile", b: "A weekly word limit (8,000 words when I checked in September; the page now just says \"limited words\")" },
    { label: "Pro, billed yearly", a: "$12/month ($144/year)", b: "$12/month per member" },
    { label: "Pro, billed monthly", a: "$15/month", b: "$30/month" },
    { label: "Student discount", a: "50% off Pro with an education email", b: "A student program exists; terms not on the pricing page" },
    { label: "Platforms", a: "Mac, Windows, iPhone, Android", b: "Mac, Windows, Linux, iPhone, Android" },
    { label: "Where your speech is processed", a: "On Wispr's servers", b: "On Typeless's servers, with zero data retention" },
    { label: "Works offline", a: "No", b: "No" },
    { label: "Extras", a: "Meeting Notetaker (Mac and Windows)", b: "Translation, per-app tones, whisper mode, \"ask anything\"" },
    { label: "Compliance (their claims)", a: "SOC 2 Type II, ISO 27001, HIPAA on higher plans", b: "ISO 27001, GDPR, HIPAA; BAA on Enterprise" },
  ],
  sections: [
    {
      heading: "Where Wispr Flow wins",
      paragraphs: [
        "Monthly billing. If you don't want to commit to a year, Flow is $15 a month and Typeless is $30. That's the single biggest price difference between them, and it's in Flow's favor.",
        "It's the default. Flow is the app most people compare everything else to, and it bundles a meeting Notetaker on Mac and Windows. If you want one subscription for dictation and meeting notes, Typeless doesn't offer that.",
        "Students get 50% off Pro with an education email, which Flow states plainly on its pricing page.",
      ],
    },
    {
      heading: "Where Typeless wins",
      paragraphs: [
        "The free plan. When I checked in September it was 8,000 words a week, four times Flow's 2,000. That's real daily use, not a trial. Typeless's pricing page now just says \"limited words\", so check the number in the app before you count on it.",
        "Linux. Typeless lists a Linux desktop app. Flow doesn't.",
        "It leans harder into editing. Translation, different tones per app and a whisper mode for quiet offices are all on the feature list.",
      ],
    },
    {
      heading: "Privacy: closer than the marketing suggests",
      paragraphs: [
        "Both send your voice to a server to be transcribed and cleaned up. Typeless says audio is processed in real time, never stored in the cloud, and that your history stays on your device. Flow offers enterprise compliance paperwork and lets you opt out of training. Both need an internet connection to work at all.",
        "If your worry is the vendor keeping your audio, read both privacy policies. If your worry is the audio leaving your computer at all, neither of these solves it.",
      ],
    },
  ],
  rhinoFit: [
    "Both are subscriptions and both are cloud services. If you only dictate on a Mac, you don't need either one.",
    "Rhino Voice does the same hold-a-key, talk, release dictation, but the speech recognition and the cleanup both run on your Mac. Turn Wi-Fi off and it still works. It's free for 2,000 words a week (unlimited your first week) and $20 once for unlimited, no account.",
    "What it doesn't do: Windows, Linux, phones, or a meeting notetaker. If you need those, pick between Flow and Typeless using the table above.",
  ],
  faq: [
    {
      question: "Is Typeless cheaper than Wispr Flow?",
      answer:
        "Billed yearly they cost the same, $12 a month. Billed monthly, Flow is $15 and Typeless is $30. Typeless's free plan is more generous.",
    },
    {
      question: "Do Wispr Flow and Typeless work offline?",
      answer:
        "No. Both process dictation on their servers and need an internet connection.",
    },
    {
      question: "Does Typeless run on Linux?",
      answer:
        "Yes, Typeless lists macOS, Windows, Linux, iOS and Android. Wispr Flow lists Mac, Windows, iPhone and Android.",
    },
    {
      question: "Is there a free alternative to both that runs on my Mac?",
      answer:
        "Rhino Voice is free for 2,000 words a week and runs entirely on your Mac, with $20 once for unlimited. superwhisper's free tier also runs local models. Apple Dictation is free and built in.",
    },
  ],
  sources: [
    "Wispr Flow pricing page and pricing FAQ (wisprflow.ai/pricing), checked October 20, 2026",
    "Typeless pricing page and homepage (typeless.com/pricing), checked October 20, 2026",
  ],
  checked: "October 2026",
};

export const metadata: Metadata = {
  title: "Wispr Flow vs Typeless (2026): Price, Free Plan, Privacy",
  description:
    "Wispr Flow vs Typeless: both $12/mo yearly, but $15 vs $30 monthly and very different free plans. An honest comparison, plus the local option.",
  alternates: { canonical: "https://rhinovoice.app/compare/wispr-flow-vs-typeless" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/compare/wispr-flow-vs-typeless",
    title: "Wispr Flow vs Typeless (2026)",
    description: "Same yearly price, very different free plans. The honest comparison.",
  },
};

export default function Page() {
  return <HeadToHeadPage content={content} />;
}
