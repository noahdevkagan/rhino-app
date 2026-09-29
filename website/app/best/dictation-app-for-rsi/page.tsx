import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-rsi",
  label: "Best dictation app for RSI and carpal tunnel",
  headline: "The best dictation app for RSI and carpal tunnel on a Mac (2026)",
  dek: "If typing hurts, the right answer depends on how much it hurts. I build one of the apps below, and I will say up front that for severe RSI it is not the first thing you should install. Here is how to match the tool to the problem.",
  shortAnswer:
    "For mild to moderate RSI, a hold-a-key dictation app takes most of your typing off your hands — you still use the keyboard and mouse to navigate, but far less. For severe RSI, where any keyboard or mouse use hurts, you need full voice control: macOS Voice Control is free and built in, and Talon Voice is the most capable option, especially for programmers.",
  shortPicks: [
    { label: "Best if you cannot use a keyboard or mouse at all", pick: "macOS Voice Control (free) or Talon Voice" },
    { label: "Best for cutting typing by most of the way", pick: "Rhino Voice — one key, cleaned-up text, $20 once (mine)" },
    { label: "Best for programmers with RSI", pick: "Talon Voice, with Cursorless" },
    { label: "Best free dictation", pick: "Apple Dictation" },
  ],
  intro: [
    {
      heading: "Two different problems",
      paragraphs: [
        "Dictation apps type for you. You still reach for the keyboard to press the dictation key, and for the mouse to click into the right box, fix a word or hit Send. For many people with wrist or forearm pain that is plenty: typing is most of the strain, and taking eighty or ninety percent of it away is what lets things heal.",
        "Voice control replaces the keyboard and mouse entirely — opening apps, clicking buttons, selecting and correcting text, all by voice. It has a steeper learning curve and is slower for pure prose, but if touching the machine hurts, it is the only category that actually helps. Many people end up using both: voice control to drive, dictation for the words.",
        "None of this replaces seeing a doctor or physiotherapist, fixing your setup, and taking breaks.",
      ],
    },
  ],
  picks: [
    {
      name: "macOS Voice Control",
      bestFor: "operating the whole Mac without touching it, for free",
      price: "Free, built into macOS",
      where: "On your Mac",
      body: [
        "Apple's built-in voice control: dictation plus commands like \"click Send\", \"open Mail\" and \"select previous word\", with numbered overlays and a grid for clicking anything on screen. Turn it on in System Settings under Accessibility. It takes a week or two to feel natural, but it is already installed and it covers the whole machine.",
      ],
      url: "https://support.apple.com/guide/mac-help/use-voice-control-mchlp2839/mac",
    },
    {
      name: "Talon Voice",
      bestFor: "power users and programmers who need to do everything by voice",
      price: "Free; a paid beta tier supports development",
      where: "On your computer",
      body: [
        "The most capable hands-free system available, built by and for people with RSI. Talon combines voice commands, a phonetic alphabet for precise editing, and optional eye tracking and noise controls, with a large community command set. Cursorless adds structural code editing in VS Code. It runs on Mac, Windows and Linux.",
        "It is a serious time investment — weeks to become fluent — and repays it if you need to do technical work without your hands.",
      ],
      url: "https://talonvoice.com/",
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "taking most of the typing off your hands with one key",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always",
      body: [
        "Mine. Hold Fn, talk, release, and polished text appears wherever the cursor is — email, Slack, documents, browser forms. The local AI pass removes filler words and false starts, so you do less correcting afterwards, which matters when every correction means reaching for the keyboard.",
        "To reduce keyboard use further, double-press Fn for hands-free recording, so you are not holding a key down while you talk, or bind a different shortcut that is comfortable for your hands. Optional spoken edits let you say \"scratch that\" instead of selecting and retyping.",
        "The honest limit: Rhino does not drive your Mac. No clicking, no app switching, no voice navigation. For severe RSI, pair it with Voice Control or use Talon instead. Apple silicon and macOS 14 or later only.",
      ],
      url: "/",
    },
    {
      name: "Apple Dictation",
      bestFor: "free dictation with no setup",
      price: "Free, built into macOS",
      where: "On your Mac, on Apple silicon with on-device dictation enabled",
      body: [
        "Free and built in. It transcribes literally, so fillers and restarts need fixing by hand afterwards — which is more keyboard work than you might want if typing is the thing that hurts.",
      ],
    },
    {
      name: "Wispr Flow",
      bestFor: "dictation on a Mac and a Windows work machine",
      price: "$15/month, or $12/month billed annually",
      where: "On Wispr's servers",
      body: [
        "Polished cleanup and apps for Mac, Windows and mobile, useful if your RSI follows you between a personal Mac and a Windows machine at work. It is cloud-processed and a subscription, and like other dictation apps it types rather than drives the computer.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  faq: [
    {
      question: "Is dictation enough if I have carpal tunnel?",
      answer:
        "For many people, yes — typing is most of the strain, and dictation removes most of the typing. If using a mouse or keyboard at all is painful, you also need voice control: macOS Voice Control (free) or Talon Voice.",
    },
    {
      question: "What is the difference between dictation and voice control?",
      answer:
        "Dictation turns speech into text at your cursor. Voice control operates the computer — opening apps, clicking, selecting and editing text — by voice. Dictation is faster for writing; voice control is necessary if you cannot use a keyboard and mouse.",
    },
    {
      question: "Can I use Rhino Voice together with macOS Voice Control?",
      answer:
        "They do different jobs, and plenty of people combine a dictation app with a voice-control system. Rhino types; Voice Control drives. Test the combination during Rhino's 30-day refund window.",
    },
    {
      question: "Can I avoid holding down a key?",
      answer:
        "Yes. In Rhino Voice, double-press the dictation key to record hands-free, then press again to stop. You can also rebind the shortcut to one that is comfortable for you.",
    },
  ],
  ctaBody:
    "$20 once, one key to dictate, and cleanup that means fewer corrections by hand. If it does not help, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for RSI and Carpal Tunnel on Mac (2026)",
  description:
    "Dictation or full voice control? How to match the tool to the severity of your RSI, with five Mac options — including the free ones — compared honestly by a competitor.",
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
