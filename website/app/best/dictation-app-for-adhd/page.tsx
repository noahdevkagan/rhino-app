import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-adhd",
  label: "Best dictation app for ADHD",
  headline: "The best dictation app for ADHD on a Mac (2026)",
  dek: "The gap between having the thought and getting it written down is where a lot of ADHD brains lose the thread. Dictation closes that gap — if the tool is fast enough to start and forgiving enough of how you actually talk. I make one of the apps below; here is the honest version.",
  shortAnswer:
    "For ADHD, the best dictation app is the one with the least friction: one key to start, no window to switch to, and AI cleanup that turns a rambling, self-correcting thought into a clean sentence. Literal transcription punishes the way many ADHD brains talk; cleanup forgives it.",
  shortPicks: [
    { label: "Best overall", pick: "Rhino Voice — one key, cleanup, spoken corrections, $20 once (mine)" },
    { label: "Best free way to test the habit", pick: "Apple Dictation" },
    { label: "Best across Mac, PC and phone", pick: "Wispr Flow" },
    { label: "Best for capturing thoughts on the go", pick: "voice memos, transcribed later in MacWhisper" },
  ],
  intro: [
    {
      heading: "Friction is the whole game",
      paragraphs: [
        "If starting a dictation takes opening an app, clicking a button and waiting, the thought is gone before the microphone is. The tools that stick for ADHD are the ones that work from wherever you already are: hold a key in the email you are writing, say it, let go, done. No new window to get distracted by.",
        "The second thing is forgiveness. ADHD speech often loops: you start a sentence, jump to a better idea, circle back, correct yourself. A literal transcript of that is harder to use than a blank page. What you want is a tool that removes the false starts and filler and hands you the sentence you meant.",
      ],
    },
    {
      heading: "What dictation will not fix",
      paragraphs: [
        "It will not organise your ideas for you, and it is not a treatment for anything. What it does well is reduce the cost of getting a thought out of your head and into the place it needs to go — a reply you have been avoiding, a first draft, a task note — before the moment passes. For a lot of people that is the difference between the email getting sent and not.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "getting thoughts out with one key and no cleanup afterwards",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always",
      body: [
        "Mine. Hold Fn anywhere, talk, release, and the cleaned-up text appears at your cursor. There is no window to open and nothing to switch to, and the recording starts the moment you press, even if the app you are in is slow. Double-press Fn to go hands-free if you think better pacing around.",
        "Turn on spoken edits and you can change your mind out loud — \"the meeting is Tuesday… actually, make that Thursday\" — and only the corrected version is typed. Say \"scrap all of that\" to start over. The local AI pass removes the ums and restarts either way.",
        "A one-time price also means no subscription to forget to cancel. It needs Apple silicon and macOS 14 or later.",
      ],
      url: "/",
    },
    {
      name: "Apple Dictation",
      bestFor: "testing whether the habit sticks before paying",
      price: "Free, built into macOS",
      where: "On your Mac, on Apple silicon with on-device dictation enabled",
      body: [
        "Free and already there — press the dictation shortcut and talk. A good way to find out whether speaking works better for you than typing. The catch is that it transcribes literally, so every loop and restart ends up in the text, which is exactly the part that tends to get in the way.",
      ],
    },
    {
      name: "Wispr Flow",
      bestFor: "a polished experience on every device",
      price: "$15/month, or $12/month billed annually",
      where: "On Wispr's servers",
      body: [
        "Excellent cleanup, fast, and on Mac, Windows and mobile, so the same habit works on your phone. The trade-offs are that it runs in the cloud and it is a subscription — worth checking you will actually keep using it before the annual plan.",
      ],
      url: "https://wisprflow.ai/",
    },
    {
      name: "superwhisper",
      bestFor: "a free local tier if you enjoy tweaking",
      price: "Free tier; Pro around $8.49/month, with a lifetime option",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      body: [
        "Powerful and very configurable, with a free tier that runs locally. The honest caution for ADHD is that the configurability is itself a rabbit hole — some people love building the perfect set of modes, and some spend the afternoon on it instead of the email.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "MacWhisper",
      bestFor: "turning voice memos into text later",
      price: "Free tier; Pro is a one-time licence, around €59 on Gumroad",
      where: "On your Mac",
      body: [
        "If your best ideas come while walking or driving, record them on your phone and drop the memos into MacWhisper afterwards for a local transcript. Capture now, sort later.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
  ],
  faq: [
    {
      question: "Does dictation help with ADHD?",
      answer:
        "Many people with ADHD find it lowers the barrier to writing: speaking is faster than typing, so a thought is captured before it slips away. It is a tool rather than a treatment, and it works best when starting a dictation takes a single key press.",
    },
    {
      question: "What if I ramble or change my mind mid-sentence?",
      answer:
        "Choose an app with AI cleanup, which removes filler words and false starts. Rhino Voice also has optional spoken edits, so saying \"actually, make that Thursday\" replaces what came before instead of typing both.",
    },
    {
      question: "What if I forget I am recording?",
      answer:
        "Rhino Voice copies any recording of five minutes or more to your clipboard instead of pasting it, so a forgotten session does not dump a wall of text into whatever window is focused. Press Esc to cancel a recording at any time.",
    },
    {
      question: "Is there a free option?",
      answer:
        "Apple Dictation is free and built into macOS, and superwhisper has a free local tier. Rhino Voice has no free tier but offers a 30-day money-back guarantee.",
    },
  ],
  ctaBody:
    "$20 once — no subscription to forget about. One key to start, cleanup that forgives how you talk, and nothing leaves your Mac. If it does not earn its keep, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for ADHD on Mac (2026): Less Friction, Fewer Lost Thoughts",
  description:
    "For ADHD, the right dictation app starts with one key and cleans up rambling, self-correcting speech. Five Mac options compared honestly by a competitor.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-adhd" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-adhd",
    title: "Best Dictation App for ADHD on Mac (2026)",
    description: "Friction is the whole game. The tools that get a thought down before it goes.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
