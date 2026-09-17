import type { Metadata } from "next";
import { ComparisonPage, type ComparisonContent } from "../../_components/comparison-page";

const content: ComparisonContent = {
  slug: "/vs/wispr-flow",
  competitor: "Wispr Flow",
  headline: "Rhino vs Wispr Flow (2026): $20 once, on your Mac — or $15 a month, in their cloud",
  dek: "Wispr Flow is the best-known dictation app on the Mac, and it is genuinely good. It also sends your audio to a server and bills you every month. Here is the honest comparison, written by the person who built the competitor.",
  shortAnswer:
    "Wispr Flow and Rhino do the same job — hold a key, talk, get clean text in whatever app you are in — but they make opposite trade-offs. Wispr Flow processes your speech in the cloud on a $15/month subscription and runs on Mac, Windows, iPhone and Android. Rhino processes everything on your own Apple silicon Mac, works with Wi-Fi off, costs $20 once, and is Mac-only.",
  pickThem:
    "you dictate on more than one kind of device, you want the polish and support of a funded team, or a monthly bill is easier to justify than reading a privacy policy.",
  pickRhino:
    "your words are the sensitive part — client calls, medical notes, legal drafts, unreleased work — or you are simply done renting a feature that your Mac is fast enough to run by itself.",
  tableCaption: "Rhino vs Wispr Flow at a glance",
  checked: "September 2026",
  rows: [
    { label: "Price", rhino: "$20 once, forever", them: "$15/month, or $12/month billed annually" },
    { label: "Free tier", rhino: "None — 30-day money-back guarantee instead", them: "Yes, capped at 2,000 words/week on desktop" },
    { label: "Where your speech is processed", rhino: "On your Mac, always", them: "On their servers" },
    { label: "Works offline", rhino: "Yes, once your model is downloaded", them: "No — dictation needs a connection" },
    { label: "Account required", rhino: "No account, no sign-in, no telemetry", them: "Yes" },
    { label: "Platforms", rhino: "macOS 14+ on Apple silicon only", them: "Mac, Windows, iPhone, Android" },
    { label: "AI cleanup of your text", rhino: "Yes, from a model running on your Mac", them: "Yes, in the cloud" },
    { label: "Custom vocabulary", rhino: "Yes, stored locally", them: "Yes" },
    { label: "Compliance paperwork", rhino: "None to sign — the audio never leaves the device", them: "SOC 2 Type II, ISO 27001, HIPAA-ready with a signed BAA" },
    { label: "Built by", rhino: "One person (me)", them: "A venture-funded team" },
  ],
  sections: [
    {
      heading: "The real difference is not the feature list",
      paragraphs: [
        "Put the two side by side and the daily experience is remarkably similar. You hold a key, you talk, you release, and clean text appears where your cursor was. Both handle filler words, both fix your punctuation, both let you teach them names they keep getting wrong. If you only ever compared the two on a feature grid you would have a hard time choosing.",
        "The difference is architectural. Wispr Flow streams your audio to a server, transcribes it there, cleans it up there, and sends the text back. Rhino does all three steps on your Mac and never opens a socket to do it. Everything else — the pricing model, the offline behaviour, the account requirement, the compliance paperwork — falls out of that one decision.",
      ],
    },
    {
      heading: "What Wispr Flow is genuinely better at",
      paragraphs: [
        "It runs everywhere. Mac, Windows, iPhone, Android — if you dictate on your phone as much as your laptop, Rhino has no answer for you and I am not going to pretend otherwise. Rhino is a Mac app and will stay one.",
        "It is easier to start. Wispr Flow signs you in and works. Rhino asks you to download a speech model the first time, which takes a few minutes and some disk space, because that model is the thing that keeps your audio at home.",
        "It has a company behind it. A funded team ships features faster than I do, staffs a support desk, and can hand an enterprise buyer a SOC 2 report and a signed BAA. If your procurement team needs a vendor questionnaire answered, that is a real advantage — Rhino's answer to the same question is stranger and simpler: there is no vendor to assess, because nothing is transmitted.",
      ],
    },
    {
      heading: "What Rhino is genuinely better at",
      paragraphs: [
        "Nothing leaves the machine. Not the audio, not the transcript, not the cleaned-up text, not a usage counter. Turn off Wi-Fi and dictation still works. That is not a privacy policy you have to trust — it is a property of the software you can verify by pulling the plug.",
        "You pay once. $20, no renewal, no seat count, no per-word cap. At Wispr Flow's annual rate you pass $20 in the second month. That is not a knock on their pricing — a cloud service has a bill to pay every time you speak, and a local app does not.",
        "There is no account. No email, no password, no profile, no history sitting in someone's database with your name attached. You buy it, you run it, and the only record of what you dictated is a local history you can turn off or delete.",
        "It stays out of the way in AI apps and terminals. Dictate into Claude, ChatGPT or a terminal and Rhino skips its cleanup pass entirely, so an instruction you meant for the assistant is passed through verbatim instead of being smoothed into prose.",
      ],
    },
    {
      heading: "A note on the free tier",
      paragraphs: [
        "Wispr Flow's free plan gives you 2,000 words a week on desktop, which is roughly fifteen minutes of talking. It is a fair trial and you should use it — you will learn within a day whether hold-to-talk dictation fits how you work at all, which is the bigger question here.",
        "Rhino has no free tier. It has a 30-day money-back guarantee instead, which is the same promise arranged differently: try it properly, and if it does not earn its keep, email me and I will refund you.",
      ],
    },
  ],
  faq: [
    {
      question: "Is Rhino a drop-in replacement for Wispr Flow?",
      answer:
        "For dictation on a Mac, yes — hold a key, speak, and the cleaned-up text lands in whatever app you are using. It is not a replacement if you dictate on Windows, an iPhone or an Android device, because Rhino is macOS-only.",
    },
    {
      question: "Does Wispr Flow send my voice to the cloud?",
      answer:
        "Yes. Wispr Flow's dictation is processed on its servers, which is why it needs a connection to work. The company is SOC 2 Type II and ISO 27001 certified, offers a HIPAA-ready plan with a signed BAA, and lets you opt out of model training — but the audio does travel. Rhino's does not travel at all.",
    },
    {
      question: "Is Rhino cheaper than Wispr Flow?",
      answer:
        "Yes, after the first two months. Rhino is $20 once. Wispr Flow Pro is $15 a month, or $12 a month billed annually, so a year of it costs roughly seven times what Rhino costs in total.",
    },
    {
      question: "Does Rhino work offline?",
      answer:
        "Yes. Once you have downloaded a speech model, dictation and the AI cleanup pass both run with the network off. Rhino only ever reaches the network to check for signed app updates and to download models you explicitly ask for.",
    },
    {
      question: "What are Rhino's system requirements?",
      answer:
        "An Apple silicon Mac running macOS 14 or later. Intel Macs are not supported, because the on-device speech and cleanup models depend on Apple silicon to run fast enough to be useful.",
    },
    {
      question: "Can I use Rhino for HIPAA-regulated or privileged work?",
      answer:
        "Talk to your own compliance people, not to me. What I can tell you is the technical fact that matters to that conversation: Rhino performs no transmission of audio or transcripts, so there is no processor to sign a business associate agreement with and no third party holding your recordings.",
    },
  ],
};

export const metadata: Metadata = {
  title: "Rhino vs Wispr Flow (2026): On-Device $20 vs Cloud Subscription",
  description:
    "Wispr Flow processes your voice in the cloud for $15/month. Rhino does the same job entirely on your Mac for $20 once. An honest head-to-head from Rhino's founder.",
  alternates: { canonical: "https://rhinovoice.app/vs/wispr-flow" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/vs/wispr-flow",
    title: "Rhino vs Wispr Flow (2026): On-Device $20 vs Cloud Subscription",
    description:
      "Same job, opposite trade-offs: a cloud subscription versus an app that never sends your voice anywhere. Honest comparison from Rhino's founder.",
  },
};

export default function Page() {
  return <ComparisonPage content={content} />;
}
