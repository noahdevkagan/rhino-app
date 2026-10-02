import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-students",
  label: "Best dictation app for students",
  headline: "The best dictation app for students on Mac (2026)",
  dek: "Essays, notes, emails to professors, discussion posts. Students write the most and have the least money. So I'm starting with the free stuff, even though I sell one of the paid apps below.",
  shortAnswer:
    "Most students should start free: Apple Dictation is built into every Mac, and Google Docs voice typing works in Chrome. If you dictate a lot and want the ums and false starts removed automatically, a one-time purchase beats a subscription over a degree. Use dictation to get your own words down faster, not as a replacement for them.",
  shortPicks: [
    { label: "Best free option", pick: "Apple Dictation" },
    { label: "Best free option for Google Docs", pick: "Google Docs voice typing" },
    { label: "Best one-time purchase", pick: "Rhino Voice. $20 once, lasts your whole degree (mine)" },
    { label: "Best for transcribing recorded lectures", pick: "MacWhisper" },
  ],
  intro: [
    {
      heading: "Do the math",
      paragraphs: [
        "A $12 to $15 monthly subscription is $576 to $720 over a four-year degree. That's a lot of burritos.",
        "That's not a reason to never pay for one if it's actually better for you. It's a reason to try the free tools first, and if you pay at all, pay once.",
      ],
    },
    {
      heading: "Is dictating your essay cheating?",
      paragraphs: [
        "No. Dictating your own essay is typing with your voice. The ideas and words are yours. That's totally different from having AI write it for you.",
        "Dictation apps with AI cleanup remove filler words and fix punctuation. They don't write arguments. But if your class has rules about AI tools, read them, and when in doubt, turn cleanup off. If you have accommodations for dictation, use whatever your disability services office supports.",
      ],
    },
  ],
  picks: [
    {
      name: "Apple Dictation",
      bestFor: "free dictation in every app on your Mac",
      price: "Free, built into macOS",
      where: "On your Mac (Apple silicon, on-device dictation on)",
      local: "Yes",
      body: [
        "Already on your Mac. Works in Pages, Word, your browser, everywhere. On newer Macs it runs on-device. It types literally, so ums and restarts need editing out. For a lot of students, it's all you'll ever need.",
      ],
    },
    {
      name: "Google Docs voice typing",
      bestFor: "students who live in Google Docs",
      price: "Free with a Google account",
      where: "In Google's cloud",
      local: "No",
      body: [
        "Open a doc in Chrome, click Tools, then Voice typing. Free, lots of languages, and it understands basic spoken punctuation like \"period\" and \"new line.\" It only works inside Google Docs in Chrome, and your speech goes to Google.",
      ],
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "heavy dictation without a subscription",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. Hold Fn anywhere, talk, let go, and clean text lands at your cursor: Google Docs, Word, Canvas, email. The AI cleanup removes filler words and false starts, so your spoken draft reads like a draft, not a transcript. Works offline, so bad library Wi-Fi doesn't matter.",
        "Add course terms, authors and names to the custom dictionary and they come back spelled right. One payment covers your whole degree and every Mac you own. Needs an Apple silicon Mac on macOS 14 or newer. No free tier, just the 30-day refund.",
      ],
      url: "/",
    },
    {
      name: "MacWhisper",
      bestFor: "turning recorded lectures into searchable text",
      price: "Free tier; Pro is about €59 once on Gumroad",
      where: "On your Mac",
      local: "Yes",
      body: [
        "Record a lecture (ask first), drop the file in, get a transcript you can search and study from. Runs on your Mac. The free tier is enough for most students.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
    {
      name: "Typeless",
      bestFor: "a big free cloud tier across devices",
      price: "Free tier of 8,000 words/week; Pro $12/month billed yearly",
      where: "In their cloud",
      local: "No",
      body: [
        "If you want AI cleanup for free and don't care about the cloud, the free tier is big enough for a lot of coursework, and it works on more than just your Mac.",
      ],
      url: "https://typeless.com/",
    },
  ],
  verdict: [
    "Start with Apple Dictation. It's free and it's already on your Mac. If you're mostly in Google Docs, try Google's voice typing too.",
    "Only pay if you're dictating every day and cleaning up the mess is eating your time. If you do pay, pay once. Don't sign up for a subscription that runs your whole degree.",
  ],
  today: [
    "Turn on Apple Dictation (System Settings → Keyboard → Dictation).",
    "Take the next assignment you're dreading and talk the first draft out loud for 10 minutes. Don't fix anything yet.",
    "Edit it at the keyboard. Compare how long that took versus starting from a blank page.",
    "If you're doing this every day and want the ums gone automatically, try Rhino. Refund inside 30 days if it's not worth it.",
  ],
  faq: [
    {
      question: "Is using dictation for essays cheating?",
      answer:
        "Dictating your own words is the same as typing them. AI cleanup that removes filler words and fixes punctuation doesn't write content for you. Check your class's policy on AI tools, and turn cleanup off if you want to be sure.",
    },
    {
      question: "What's the best free dictation app for Mac?",
      answer:
        "Apple Dictation. It's built into macOS and runs on-device on Apple silicon. For Google Docs specifically, Google Docs voice typing in Chrome is also free.",
    },
    {
      question: "Can I transcribe my lecture recordings?",
      answer:
        "Yes. MacWhisper transcribes audio files on your Mac, and Rhino Voice can transcribe a file you drop in too. Always ask before recording a lecture.",
    },
    {
      question: "Is there a student discount for Rhino Voice?",
      answer:
        "Rhino is $20 once for everyone. That's less than two months of most dictation subscriptions.",
    },
  ],
  ctaBody:
    "$20 once for your whole degree. No subscription, no account, works offline. Try it for 30 days. If it's not worth it, email me and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Students on Mac (2026): Free Options First",
  description:
    "The free dictation tools every student already has, when a paid app is worth it, and how to dictate essays without crossing academic honesty lines. Five options compared.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-students" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-students",
    title: "Best Dictation App for Students on Mac (2026)",
    description: "Start free. Pay once if you pay at all. Dictation for essays, notes and lectures.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
