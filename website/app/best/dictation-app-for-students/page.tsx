import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-students",
  label: "Best dictation app for students",
  headline: "The best dictation app for students on a Mac (2026)",
  dek: "Essays, notes, emails to professors, discussion posts. Students have the most to write and the least to spend, so this page leads with the free options. I make one of the paid apps below and I have tried to keep that from tilting the order.",
  shortAnswer:
    "Most students should start free: Apple Dictation is built into every Mac, and Google Docs voice typing works in Chrome. If you dictate a lot and want the ums and false starts removed automatically, a one-time purchase beats a subscription over a degree. Use dictation to draft your own words — not as a substitute for them.",
  shortPicks: [
    { label: "Best free option", pick: "Apple Dictation" },
    { label: "Best free option for Google Docs", pick: "Google Docs voice typing" },
    { label: "Best one-time purchase", pick: "Rhino Voice — $20 once, lasts the whole degree (mine)" },
    { label: "Best for transcribing recorded lectures", pick: "MacWhisper" },
  ],
  intro: [
    {
      heading: "Do the maths over four years",
      paragraphs: [
        "A $12–$15 monthly dictation subscription is $500–$700 over a four-year degree. That is not a reason to avoid one if it is genuinely better for you, but it is a reason to try the free tools first and to prefer a one-time purchase if you end up paying at all.",
      ],
    },
    {
      heading: "Dictation and academic honesty",
      paragraphs: [
        "Dictating your own essay is typing with your voice; the words and ideas are yours. That is a different thing from having an AI write it. Dictation apps with AI cleanup remove filler words and fix punctuation — they do not write arguments for you — but if your course has rules about AI tools, read them, and if in doubt, switch cleanup off. Students with accommodations for dictation should use whatever their disability services office supports.",
      ],
    },
  ],
  picks: [
    {
      name: "Apple Dictation",
      bestFor: "free dictation in every app on your Mac",
      price: "Free, built into macOS",
      where: "On your Mac, on Apple silicon with on-device dictation enabled",
      body: [
        "Already on your Mac, works in Pages, Word, the browser and everywhere else. On Apple silicon it runs on-device for supported languages. It transcribes literally, so ums and restarts need editing out, but for many students it is all they will ever need.",
      ],
    },
    {
      name: "Google Docs voice typing",
      bestFor: "students who live in Google Docs",
      price: "Free with a Google account",
      where: "In Google's cloud",
      body: [
        "Open a document in Chrome and choose Tools, then Voice typing. It is free, supports many languages, and understands basic spoken punctuation. It only works inside Google Docs in Chrome, and your speech is processed by Google.",
      ],
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "heavy dictation without a subscription",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always",
      body: [
        "Mine. Hold Fn anywhere, talk, release, and the cleaned-up text lands at your cursor — Google Docs, Word, Canvas, email. The local AI pass removes filler words and false starts, so a spoken first draft reads like a first draft rather than a transcript. It works offline, including in a library with bad Wi-Fi.",
        "Add course terms, authors and names to the custom dictionary and they come back spelled right. One payment covers your whole degree and every Mac you own. It needs an Apple silicon Mac on macOS 14 or later, and there is no free tier — just the 30-day refund.",
      ],
      url: "/",
    },
    {
      name: "MacWhisper",
      bestFor: "turning recorded lectures into searchable text",
      price: "Free tier; Pro is a one-time licence, around €59 on Gumroad",
      where: "On your Mac",
      body: [
        "Record a lecture (with permission), drop the file in, and get a local transcript to search and study from. The free tier is enough for many students; Pro adds batch jobs and more models.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
    {
      name: "Typeless",
      bestFor: "a generous free cloud tier across devices",
      price: "Free tier of 8,000 words/week; Pro $12/month billed annually",
      where: "In their cloud",
      body: [
        "If you want AI cleanup for free and do not mind the cloud, Typeless's free tier is big enough for a lot of coursework, and it works on more than just a Mac.",
      ],
      url: "https://typeless.com/",
    },
  ],
  faq: [
    {
      question: "Is using dictation for essays cheating?",
      answer:
        "Dictating your own words is not different from typing them. AI cleanup that removes filler words and fixes punctuation does not write content for you. Check your course's policy on AI tools, and switch cleanup off if you want to be certain.",
    },
    {
      question: "What is the best free dictation app for Mac?",
      answer:
        "Apple Dictation, which is built into macOS and runs on-device on Apple silicon. For Google Docs specifically, Google Docs voice typing in Chrome is also free.",
    },
    {
      question: "Can I transcribe my lecture recordings?",
      answer:
        "Yes. MacWhisper transcribes audio files locally on your Mac, and Rhino Voice can transcribe a dropped-in file too. Always get permission before recording a lecture.",
    },
    {
      question: "Is there a student discount for Rhino Voice?",
      answer:
        "Rhino is $20 once for everyone, which works out cheaper than a single month of most dictation subscriptions.",
    },
  ],
  ctaBody:
    "$20 once for your whole degree — no subscription, no account, works offline. If it does not earn its keep, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Students on Mac (2026): Free Options First",
  description:
    "Free dictation tools every student already has, when a paid app is worth it, and how to dictate essays without crossing academic-honesty lines. Five options compared.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-students" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-students",
    title: "Best Dictation App for Students on Mac (2026)",
    description: "Start free, pay once if you pay at all. Dictation for essays, notes and lectures.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
