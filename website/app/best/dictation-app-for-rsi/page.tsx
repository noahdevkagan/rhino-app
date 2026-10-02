import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-rsi",
  label: "Best dictation app for RSI and carpal tunnel",
  headline: "The best dictation app for RSI and carpal tunnel on Mac (2026)",
  dek: "If typing hurts, the right tool depends on how much it hurts. I make one of the apps below, and I'll tell you straight: if your RSI is bad, mine is not the first thing you should install. Here's how to match the tool to the problem.",
  shortAnswer:
    "For mild to moderate RSI, a hold-a-key dictation app takes most of the typing off your hands. You still use the keyboard and mouse to get around, just way less. For severe RSI, where any keyboard or mouse use hurts, you need full voice control: macOS Voice Control is free and built in, and Talon Voice is the most capable option, especially for programmers.",
  shortPicks: [
    { label: "Best if you can't use a keyboard or mouse", pick: "macOS Voice Control (free) or Talon Voice" },
    { label: "Best for cutting most of your typing", pick: "Rhino Voice. One key, clean text, $20 once (mine)" },
    { label: "Best for programmers with RSI", pick: "Talon Voice, with Cursorless" },
    { label: "Best free dictation", pick: "Apple Dictation" },
  ],
  intro: [
    {
      heading: "Two different problems",
      paragraphs: [
        "Dictation apps type for you. You still press a key to start and use the mouse to click into the right box, fix a word, or hit Send. For a lot of people with wrist or forearm pain, that's enough. Typing is most of the strain, and taking most of it away is what gives you room to heal.",
        "Voice control replaces the keyboard and mouse completely. Open apps, click buttons, select and fix text, all by voice. It takes longer to learn and it's slower for writing. But if touching the computer hurts, it's the only thing that actually helps.",
        "A lot of people use both: voice control to drive, dictation for the words. And none of this replaces seeing a doctor or physical therapist, fixing your desk setup, and taking breaks.",
      ],
    },
  ],
  picks: [
    {
      name: "macOS Voice Control",
      bestFor: "running your whole Mac without touching it, free",
      price: "Free, built into macOS",
      where: "On your Mac",
      local: "Yes",
      body: [
        "Apple's built-in voice control. Dictation plus commands like \"click Send,\" \"open Mail\" and \"select previous word,\" with numbered labels and a grid for clicking anything on screen. Turn it on in System Settings under Accessibility. Takes a week or two to feel natural. But it's already installed and it covers the whole machine.",
      ],
      url: "https://support.apple.com/guide/mac-help/use-voice-control-mchlp2839/mac",
    },
    {
      name: "Talon Voice",
      bestFor: "power users and programmers who need to do everything by voice",
      price: "Free; paid beta tier supports development",
      where: "On your computer",
      local: "Yes",
      body: [
        "The most capable hands-free system out there, built by and for people with RSI. Voice commands, a phonetic alphabet for precise editing, optional eye tracking, and a big community command set. Cursorless adds code editing in VS Code by voice. Mac, Windows and Linux.",
        "It's a real time investment. Weeks to get fluent. Worth it if you need to do technical work without your hands.",
      ],
      url: "https://talonvoice.com/",
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "taking most of the typing off your hands with one key",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. Hold Fn, talk, let go, and clean text shows up wherever your cursor is: email, Slack, docs, forms. The AI cleanup removes filler words and false starts, so you fix less afterward. That matters when every fix means reaching for the keyboard.",
        "To use the keyboard even less: double-press Fn to record hands-free so you're not holding a key while you talk, or pick a different shortcut that's comfortable for your hands. Turn on spoken edits and you can say \"scratch that\" instead of selecting and retyping.",
        "The honest limit: Rhino doesn't drive your Mac. No clicking, no switching apps, no voice navigation. For severe RSI, pair it with Voice Control or use Talon. Apple silicon and macOS 14 or newer only.",
      ],
      url: "/",
    },
    {
      name: "Apple Dictation",
      bestFor: "free dictation with zero setup",
      price: "Free, built into macOS",
      where: "On your Mac (Apple silicon, on-device dictation on)",
      local: "Yes",
      body: [
        "Free and built in. It types exactly what you say, so ums and restarts need fixing by hand afterward. That's more keyboard time than you want if typing is what hurts.",
      ],
    },
    {
      name: "Wispr Flow",
      bestFor: "dictation on a Mac at home and Windows at work",
      price: "$15/month, or $12/month billed yearly",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "Good cleanup and apps for Mac, Windows and phone. Useful if your RSI follows you between a personal Mac and a work PC. It's cloud and a subscription, and like the other dictation apps, it types but doesn't drive your computer.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  verdict: [
    "If it hurts to use the mouse at all: set up macOS Voice Control today. It's free. If you write code, start learning Talon this week.",
    "If typing is the problem but the mouse is okay: a dictation app will take most of the load off. Try free Apple Dictation first. If fixing its mistakes by hand is still too much typing, Rhino's cleanup is built for exactly that.",
  ],
  today: [
    "Turn on Voice Control (System Settings → Accessibility → Voice Control) and try \"open Safari\" and \"show numbers.\" Just see how it feels.",
    "Turn on Apple Dictation (System Settings → Keyboard → Dictation) and write your next three emails by voice.",
    "Book the doctor or PT appointment you've been putting off. Software helps. It doesn't heal.",
    "If you want cleaner text with less fixing, try Rhino with hands-free mode for a week. Refund if it doesn't help.",
  ],
  faq: [
    {
      question: "Is dictation enough if I have carpal tunnel?",
      answer:
        "For a lot of people, yes. Typing is most of the strain, and dictation removes most of the typing. If using a mouse or keyboard at all hurts, you also need voice control: macOS Voice Control (free) or Talon Voice.",
    },
    {
      question: "What's the difference between dictation and voice control?",
      answer:
        "Dictation turns speech into text at your cursor. Voice control runs the computer by voice: opening apps, clicking, selecting and editing text. Dictation is faster for writing. Voice control is necessary if you can't use a keyboard and mouse.",
    },
    {
      question: "Can I use Rhino Voice with macOS Voice Control?",
      answer:
        "They do different jobs, and plenty of people pair a dictation app with voice control. Rhino types, Voice Control drives. Test the combo during Rhino's 30-day refund window.",
    },
    {
      question: "Can I avoid holding down a key?",
      answer:
        "Yes. In Rhino Voice, double-press the dictation key to record hands-free, then press again to stop. You can also change the shortcut to one that's comfortable for you.",
    },
  ],
  ctaBody:
    "$20 once. One key to dictate, and cleanup that means less fixing by hand. If it doesn't help your hands within 30 days, email me and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for RSI and Carpal Tunnel on Mac (2026)",
  description:
    "Dictation or full voice control? How to match the tool to how bad your RSI is, with five Mac options including the free ones. From someone who makes one of them.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-rsi" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-rsi",
    title: "Best Dictation App for RSI and Carpal Tunnel on Mac (2026)",
    description: "If typing hurts, the right tool depends on how much. Dictation vs voice control, explained.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
