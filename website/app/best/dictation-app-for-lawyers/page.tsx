import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-lawyers",
  label: "Best dictation app for lawyers",
  headline: "The best dictation app for lawyers on Mac (2026)",
  dek: "Full disclosure: I make one of these apps. So yes, I'm biased. I'm going to tell you what I'd actually use if I were a lawyer, including the ones that aren't mine. Short version: accuracy is basically solved. The question that matters for you is where your words go.",
  shortAnswer:
    "For lawyers, the deciding question is whether privileged material leaves your computer. Dictation that runs on your Mac is now accurate enough for memos, letters and client email, and it means there's no vendor to review and nothing sitting on someone else's server. Cloud tools can work, but they turn dictation into a vendor-risk decision your firm has to approve.",
  shortPicks: [
    { label: "Best for privileged work", pick: "Rhino Voice. On-device only, $20 once (mine)" },
    { label: "Best free option", pick: "Apple Dictation" },
    { label: "Best for recorded memos", pick: "MacWhisper" },
    { label: "Best if your firm runs on Windows", pick: "Dragon Legal" },
  ],
  intro: [
    {
      heading: "Why privilege changes everything",
      paragraphs: [
        "Most dictation apps work like this: your audio goes to their server, gets turned into text, comes back. For a sales email, who cares. For a settlement strategy, a note about your client's exposure, or an email about a deal that isn't public yet? That's a copy of privileged content passing through a third party.",
        "Plenty of firms allow that with the right contracts. But here's the simpler move: skip the question entirely. If transcription happens on your own Mac and nothing is sent anywhere, there's no vendor holding your audio, no data agreement to negotiate, and nothing for IT to flag. On a modern Mac you give up almost nothing to get that.",
      ],
    },
    {
      heading: "Lawyers do three different jobs with dictation",
      paragraphs: [
        "1. Drafting. Letters, memos, emails, file notes. This is most of it, and it's what hold-a-key dictation apps are for.",
        "2. Transcribing recordings. The memo you dictated into your phone in the car. The client interview you recorded (with permission). That's a file job, and a transcription app does it better.",
        "3. Official records. Depositions and hearings. None of this software produces a certified transcript. That's still the court reporter's job.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "privileged drafting where nothing can leave the machine",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac. There's no cloud option in the app, period.",
      local: "Yes, always",
      body: [
        "This is mine. I built it so the privacy question has one answer: speech recognition and AI cleanup both run on your Mac. No account. Works with Wi-Fi off. Hold Fn, say the paragraph, let go, and clean text shows up in Word, Outlook, Clio, or whatever box your cursor is in. Punctuated, with the ums and restarts removed.",
        "The custom dictionary is where it pays for itself. Add your client names, opposing counsel, case names, the Latin you actually use. Rhino fixes the spelling and also catches the ways it tends to mishear them. History stays on your Mac, and you can set it to auto-delete or turn it off completely.",
        "What it won't do: control your computer by voice. And it needs an Apple silicon Mac on macOS 14 or newer. If your firm is on Windows, skip it.",
      ],
      url: "/",
    },
    {
      name: "Apple Dictation",
      bestFor: "seeing if you need to pay anyone at all",
      price: "Free, built into macOS",
      where: "On your Mac (Apple silicon, on-device dictation on)",
      local: "Yes",
      body: [
        "It's already on your Mac. Hit the dictation shortcut and talk. For quick replies and file notes, it's fine, and it costs nothing to try.",
        "The problem: it types exactly what you say. Every \"um,\" every restart, every \"sorry, strike that\" lands in the document. For anything longer than a couple sentences, you spend the time you saved cleaning it up.",
      ],
    },
    {
      name: "MacWhisper",
      bestFor: "turning recorded memos and interviews into text",
      price: "Free tier; Pro is about €59 once on Gumroad",
      where: "On your Mac",
      local: "Yes",
      body: [
        "If you dictate into your phone on the go and deal with it later, you want a transcription app, and this is the best one on Mac. Runs locally, handles long recordings. Pro adds speaker labels and batch jobs, which is great for a recorded client interview where you need to know who said what.",
        "The Gumroad version also does live dictation, so for some lawyers one purchase covers both.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
    {
      name: "superwhisper",
      bestFor: "a free local tier with tons of settings",
      price: "Free tier; Pro about $8.49/month, lifetime available",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      local: "Optional",
      body: [
        "Solid Mac dictation app. The free tier runs locally, so it's a zero-dollar way to try modern dictation. Pro adds custom modes, like one that formats a dictated letter a specific way.",
        "The catch for a firm: it also offers cloud models. Great for most people. For a no-cloud policy, it means trusting every lawyer to keep the right setting picked.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "Dragon Legal (Windows)",
      bestFor: "firms already built around Dragon and Windows",
      price: "Several hundred dollars, one-time, Windows only",
      where: "On the Windows PC running it",
      local: "No Mac version",
      body: [
        "Dragon Legal still exists for Windows. Decades of legal vocabulary and a macro system some firms built entire workflows on. If that's your firm, a Mac app won't replace it, and I'm not going to pretend otherwise.",
        "On a Mac, that means running Windows in a virtual machine or keeping a PC on your desk. Doable. Annoying.",
      ],
    },
    {
      name: "Wispr Flow",
      bestFor: "firms that already approved a cloud vendor",
      price: "$15/month, or $12/month billed yearly",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "The most polished cloud dictation product out there. Works on Mac, Windows and phone. It has SOC 2 Type II and ISO 27001, which is the paperwork your firm's vendor review will ask for.",
        "It's still cloud. Your dictation goes to their servers. If your firm reviewed that and said yes, it's a great product. If nobody has asked yet, ask before you dictate a client matter into it.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  verdict: [
    "If you're a solo or small-firm lawyer on a Mac: get something that runs locally and move on with your life. Try Apple Dictation first because it's free. If the ums and cleanup drive you nuts (they will), that's the gap Rhino fills for $20.",
    "If you're at a bigger firm: ask IT what's already approved before you buy anything. If the answer is \"Dragon on Windows,\" use Dragon. If it's \"nothing,\" local dictation is the easiest thing to get approved, because there's nothing to approve.",
  ],
  today: [
    "Turn on Apple Dictation (System Settings → Keyboard → Dictation) and dictate your next three emails. Free, five minutes.",
    "Write down the 20 names and terms you say most: clients, parties, case names. That list is your custom dictionary in any app.",
    "Ask your IT or ethics contact one question: \"Can I use cloud dictation on client matters?\" The answer decides the rest.",
    "If you want the cleanup, try Rhino on real work for a week. If it doesn't save you time, email me for a refund.",
  ],
  faq: [
    {
      question: "Is it safe for lawyers to use cloud dictation?",
      answer:
        "It can be, with the right vendor agreements and your firm's approval. Lots of firms allow it. But cloud dictation sends privileged content to a third party, which makes it a vendor-risk call. On-device dictation, where nothing is sent anywhere, avoids the question. Check your firm's policy and your state bar's guidance.",
    },
    {
      question: "Does Rhino Voice send anything to a server?",
      answer:
        "No. Audio, transcripts, history and the AI cleanup all stay on your Mac. Rhino only goes online to check for signed app updates and to download speech models you ask for. Dictation works with Wi-Fi off.",
    },
    {
      question: "Can dictation software make a deposition transcript?",
      answer:
        "Not a certified one. Apps like MacWhisper can turn a recording into a working transcript with speaker labels, which is useful for your own review. The official record still comes from a court reporter.",
    },
    {
      question: "Will it get case names and legal terms right?",
      answer:
        "Everyday legal English, yes. Names of clients, parties and cases are where it slips. Fix that with a custom dictionary: add the terms once and they come back right. Rhino, superwhisper, VoiceInk and MacWhisper all have one.",
    },
    {
      question: "Does any of this work on Windows?",
      answer:
        "Dragon Legal and Wispr Flow do. Rhino Voice, superwhisper and MacWhisper are Mac only, and Rhino needs an Apple silicon Mac on macOS 14 or newer.",
    },
  ],
  ctaBody:
    "$20 once. No subscription, no account, and nothing leaves your Mac, so there's no vendor to review. Use it on real work for 30 days. If it doesn't save you time, email me and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Lawyers on Mac (2026): Privilege-Safe Picks",
  description:
    "For lawyers, accuracy is solved. The real question is where privileged dictation goes. Six Mac options, including ones that aren't mine, with the trade-offs spelled out.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-lawyers" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-lawyers",
    title: "Best Dictation App for Lawyers on Mac (2026)",
    description: "Accuracy is solved. The question is whether privileged words leave your computer.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
