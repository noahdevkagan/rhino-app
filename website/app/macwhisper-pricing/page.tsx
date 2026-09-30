import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../_components/best-for-page";

const content: BestForContent = {
  slug: "/macwhisper-pricing",
  label: "MacWhisper pricing and discount codes",
  crumbParent: null,
  headline: "MacWhisper pricing, free tier and discount codes (2026)",
  dek: "Full disclosure: I make Rhino Voice, a different Mac app. I don't make MacWhisper and I don't have a coupon for it. But people keep asking what MacWhisper costs and whether the discount codes floating around are real, so here's the straight answer.",
  shortAnswer:
    "MacWhisper has a free tier that transcribes files on your Mac with the smaller Whisper models. Pro is a one-time license, about €59, sold on Gumroad. The Mac App Store version is sold separately with its own subscription and lifetime options. There's no permanent public discount code, but MacWhisper's support docs say students, journalists and nonprofits can email support@macwhisper.com to ask for 25% off.",
  shortPicks: [
    { label: "Is it free?", pick: "Yes, there's a real free tier with no time limit" },
    { label: "Pro price", pick: "About €59 once on Gumroad" },
    { label: "Discount code", pick: "No public code; 25% off on request for students, journalists and nonprofits" },
    { label: "Watch out for", pick: "Coupon sites and fake download sites" },
  ],
  intro: [
    {
      heading: "What the free tier gets you",
      paragraphs: [
        "The free tier is a real app, not a 7-day trial. It transcribes audio and video files on your Mac using the smaller Whisper models (Tiny and Base). Nothing gets uploaded.",
        "The catch is accuracy. Small models are fine for clear, short recordings in one language. On long recordings, noisy audio or technical vocabulary, you'll see more mistakes. That's usually when people upgrade.",
      ],
    },
    {
      heading: "What Pro adds",
      paragraphs: [
        "Pro unlocks the larger, more accurate Whisper models, batch transcription, speaker labels, subtitle export (SRT and VTT), YouTube transcription and system audio recording, among other things.",
        "The Gumroad version is a one-time license, about €59. The Mac App Store version is a separate product with its own subscription and lifetime pricing, so check which one you're buying. A Gumroad license and an App Store purchase aren't the same thing.",
      ],
    },
    {
      heading: "About those MacWhisper discount codes",
      paragraphs: [
        "Most pages promising a \"MacWhisper discount code\" are coupon farms. There's no permanent public code. Old promo codes from past sales show up everywhere and usually don't work anymore.",
        "What does exist, according to MacWhisper's support docs: 25% off for students, journalists and nonprofits. You ask for it by emailing support@macwhisper.com and telling them about your work. They also sell volume licenses for teams.",
        "One more warning: only buy from the official Gumroad store or the Mac App Store. The developer has warned about copycat sites pretending to be MacWhisper.",
      ],
    },
  ],
  picks: [
    {
      name: "MacWhisper Free",
      bestFor: "clear, short recordings where the small models are good enough",
      price: "Free",
      where: "On your Mac",
      local: "Yes",
      body: [
        "Start here. Run a few of your real recordings through it. If the transcripts are good enough, you're done and it cost nothing.",
      ],
      url: "https://www.macwhisper.com/",
      linkText: "Visit MacWhisper",
    },
    {
      name: "MacWhisper Pro (Gumroad)",
      bestFor: "anyone transcribing long, noisy or multi-speaker recordings",
      price: "About €59 once; 25% off on request for students, journalists and nonprofits",
      where: "On your Mac",
      local: "Yes",
      body: [
        "One payment, bigger models, speaker labels, batch jobs and subtitles. If transcribing files is a real part of your work, this is fair value, and it's what I'd buy for that job.",
      ],
    },
    {
      name: "Aiko",
      bestFor: "a completely free alternative for file transcription",
      price: "Free",
      where: "On your Mac",
      local: "Yes",
      body: [
        "If you don't want to pay at all, Aiko is a free Whisper-based transcription app for Mac and iPhone. No speaker labels or batch jobs, but it runs on your device and costs nothing.",
      ],
      url: "https://sindresorhus.com/aiko",
    },
    {
      name: "Buzz",
      bestFor: "free, open-source transcription with subtitle export",
      price: "Free on GitHub; paid native version on the Mac App Store",
      where: "On your Mac",
      local: "Yes",
      body: [
        "Open source, runs offline, exports TXT, SRT and VTT. Rougher around the edges than MacWhisper, but free if you download it from GitHub.",
      ],
      url: "https://github.com/chidiwilliams/buzz",
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "if you bought MacWhisper for dictation, not files",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. Lots of people look at MacWhisper when what they actually want is to talk and have text show up in their email or Slack. That's dictation. Rhino does exactly that: hold Fn, talk, let go, cleaned-up text lands in any app. It's $20, about a third of MacWhisper Pro, and runs on your Mac.",
        "It's not built for transcribing files: no speaker labels or subtitles. If files are your job, buy MacWhisper Pro. Apple silicon and macOS 14 or newer.",
      ],
      url: "/",
    },
  ],
  verdict: [
    "Try MacWhisper's free tier first. Seriously. It's free and it might be enough.",
    "If you transcribe files for work, MacWhisper Pro at about €59 once is a good deal. If you qualify, email for the 25% discount instead of hunting for codes.",
    "If you realize you wanted dictation, not transcription, skip Pro and try Rhino for $20.",
  ],
  today: [
    "Download MacWhisper's free version from its official site or Gumroad store, not a coupon site.",
    "Transcribe three of your real recordings. Check the accuracy.",
    "Good enough? Stop there. Not good enough and you're a student, journalist or nonprofit? Email support@macwhisper.com for 25% off Pro.",
    "Wanted dictation all along? Try Rhino for a week. Refund inside 30 days if it's not for you.",
  ],
  faq: [
    {
      question: "Is MacWhisper free?",
      answer:
        "Yes, there's a free tier with no time limit. It transcribes files on your Mac using the smaller Whisper models. Pro, about €59 once on Gumroad, unlocks larger models and pro features.",
    },
    {
      question: "How much is MacWhisper Pro?",
      answer:
        "About €59 as a one-time license on Gumroad. The Mac App Store version is sold separately with its own subscription and lifetime options.",
    },
    {
      question: "Is there a MacWhisper discount code?",
      answer:
        "There's no permanent public code, and most coupon-site codes are expired. MacWhisper's support docs say students, journalists and nonprofits can get 25% off by emailing support@macwhisper.com.",
    },
    {
      question: "Is MacWhisper a one-time purchase or a subscription?",
      answer:
        "The Gumroad Pro license is one-time. The Mac App Store version offers subscription and lifetime options. Check which store you're buying from.",
    },
    {
      question: "Is this MacWhisper's official site?",
      answer:
        "No. This page is by the maker of Rhino Voice, a different Mac app. For official pricing and support, go to MacWhisper's own site or its Gumroad store.",
    },
  ],
  ctaBody:
    "If what you wanted was dictation, not file transcription: $20 once, no subscription, and nothing leaves your Mac. If it doesn't save you time, email me within 30 days and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "MacWhisper Pricing (2026): Free Tier, Pro Cost, Discount Codes",
  description:
    "Is MacWhisper free? What Pro costs, Gumroad vs App Store, and which discount codes are real (hint: the 25% student discount). Not affiliated with MacWhisper.",
  alternates: { canonical: "https://rhinovoice.app/macwhisper-pricing" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/macwhisper-pricing",
    title: "MacWhisper Pricing, Free Tier and Discount Codes (2026)",
    description: "The straight answer on what MacWhisper costs and which discounts are real.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
