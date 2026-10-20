import type { Metadata } from "next";
import { HeadToHeadPage, type HeadToHeadContent } from "../../_components/head-to-head-page";

const content: HeadToHeadContent = {
  slug: "/compare/wispr-flow-vs-aqua-voice",
  a: "Wispr Flow",
  b: "Aqua Voice",
  headline: "Wispr Flow vs Aqua Voice (2026): the polished default vs the cheaper challenger",
  dek: "Full disclosure: I make Rhino Voice, which competes with both. I don't make either of these. Here's how the two compare on price, free plan and privacy, from their own pricing pages, and where a local app fits.",
  shortAnswer:
    "Aqua Voice is the cheaper of the two: Pro is $8 a month billed yearly or $10 monthly, against Wispr Flow's $12 yearly or $15 monthly. Flow's free plan is far better, 2,000 words every week against Aqua's 1,000 words to start. Both run on Mac, Windows, iPhone and Android, and both process your speech in the cloud.",
  pickA:
    "you want a generous free plan, a meeting notetaker in the same app, or the app most of the category is measured against.",
  pickB:
    "you're going to pay anyway and want the lower price, especially as a student (70% off), or you want realtime text and a \"send it\" voice command on Max.",
  rows: [
    { label: "Free plan", a: "2,000 words a week on desktop, limited on mobile", b: "1,000 free words to start" },
    { label: "Pro, billed yearly", a: "$12/month ($144/year)", b: "$8/month ($96/year)" },
    { label: "Pro, billed monthly", a: "$15/month", b: "$10/month" },
    { label: "Higher tier", a: "Growth and Enterprise for teams", b: "Max $24/month yearly or $30 monthly; Business from $19/seat" },
    { label: "Student discount", a: "50% off Pro", b: "70% off Pro and Max with a school email" },
    { label: "Platforms", a: "Mac, Windows, iPhone, Android", b: "Mac, Windows, iPhone, Android" },
    { label: "Where your speech is processed", a: "On Wispr's servers", b: "On Aqua's servers, with its own Avalon model" },
    { label: "Storage controls", a: "Opt out of training; compliance on higher plans", b: "Privacy Mode stores nothing on their servers; zero retention on Business" },
    { label: "Works offline", a: "No", b: "No" },
  ],
  sections: [
    {
      heading: "Where Wispr Flow wins",
      paragraphs: [
        "The free plan. 2,000 words every week is enough to use Flow lightly forever. Aqua's 1,000 free words are a taste, gone in about seven minutes of talking.",
        "Breadth. Flow bundles a meeting Notetaker on Mac and Windows, and its higher plans come with SOC 2 Type II and ISO 27001 for companies that need paperwork.",
      ],
    },
    {
      heading: "Where Aqua Voice wins",
      paragraphs: [
        "Price. At $96 a year, Aqua Pro is a third cheaper than Flow Pro at $144. Month to month it's $10 against $15. For students the gap is bigger: 70% off puts Aqua Pro at $2.40 a month billed yearly.",
        "Its own model. Aqua transcribes with Avalon, a model it trained itself, and publishes benchmark results for technical terms. If you dictate code or jargon, that's worth testing on your own words.",
        "Privacy Mode. Turn it on and Aqua says nothing is stored on its servers. It's still processed in the cloud, but you can keep it from piling up there.",
      ],
    },
  ],
  rhinoFit: [
    "Aqua saves you money. Neither saves your audio from leaving your computer: both need a connection, and both bill you every month or year.",
    "Rhino Voice runs the speech recognition and the cleanup on your Mac. It works with Wi-Fi off and there's no account. It's free for 2,000 words a week (unlimited your first week), and $20 once gets you unlimited, less than three months of Aqua Pro.",
    "It's Mac only, Apple silicon, macOS 14 or newer. If you dictate on Windows or your phone, choose between these two.",
  ],
  faq: [
    {
      question: "Is Aqua Voice cheaper than Wispr Flow?",
      answer:
        "Yes. Aqua Voice Pro is $8 a month billed yearly or $10 monthly. Wispr Flow Pro is $12 a month billed yearly or $15 monthly.",
    },
    {
      question: "Which has the better free plan?",
      answer:
        "Wispr Flow: 2,000 words a week on desktop. Aqua Voice's free plan is 1,000 words to start.",
    },
    {
      question: "Do Wispr Flow and Aqua Voice work offline?",
      answer: "No. Both transcribe in the cloud and need an internet connection.",
    },
    {
      question: "Is there an option that keeps my voice on my Mac?",
      answer:
        "Rhino Voice runs entirely on your Mac and works offline: free for 2,000 words a week, $20 once for unlimited. superwhisper's free tier and VoiceInk also run locally.",
    },
  ],
  sources: [
    "Wispr Flow pricing page and pricing FAQ (wisprflow.ai/pricing), checked October 20, 2026",
    "Aqua Voice pricing page and FAQ (aquavoice.com/pricing) and homepage, checked October 20, 2026",
  ],
  checked: "October 2026",
};

export const metadata: Metadata = {
  title: "Wispr Flow vs Aqua Voice (2026): Price, Free Plan, Privacy",
  description:
    "Wispr Flow vs Aqua Voice: $12 vs $8 a month yearly, 2,000 weekly free words vs 1,000 to start. An honest comparison, plus the on-device option.",
  alternates: { canonical: "https://rhinovoice.app/compare/wispr-flow-vs-aqua-voice" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/compare/wispr-flow-vs-aqua-voice",
    title: "Wispr Flow vs Aqua Voice (2026)",
    description: "The polished default vs the cheaper challenger. The honest comparison.",
  },
};

export default function Page() {
  return <HeadToHeadPage content={content} />;
}
