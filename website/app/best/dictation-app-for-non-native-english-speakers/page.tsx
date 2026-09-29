import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-non-native-english-speakers",
  label: "Best dictation app for non-native English speakers",
  headline: "The best dictation app for non-native English speakers and multilingual users on a Mac (2026)",
  dek: "Older dictation software was trained on a narrow range of accents and made anyone outside it repeat themselves. Modern speech models are far more forgiving. I build one of the apps below; this page is about what actually matters if English is your second language, or if you dictate in more than one.",
  shortAnswer:
    "Modern Whisper-family speech models handle a wide range of accents without voice training, so accent is much less of a barrier than it was. If you dictate in English with an accent, pick an app with AI cleanup and a custom dictionary. If you dictate in several languages, pick one that supports a multilingual model and lets you set or auto-detect the language — and test mixing languages mid-sentence before you rely on it.",
  shortPicks: [
    { label: "Best on-device multilingual dictation", pick: "Rhino Voice — Whisper Large v3 Turbo or Parakeet v3 locally, $20 once (mine)" },
    { label: "Best cloud option across devices", pick: "Wispr Flow" },
    { label: "Best free option", pick: "Apple Dictation, per language" },
    { label: "Best free local app with lots of models", pick: "superwhisper" },
  ],
  intro: [
    {
      heading: "Accents are no longer the problem they were",
      paragraphs: [
        "Whisper and its successors were trained on huge amounts of speech from many countries, and they do not need a voice-training session before they understand you. In practice, a clear speaker with a strong accent now gets accurate results out of the box far more often than with the dictation software of ten years ago.",
        "Where things still go wrong is names and specialist words — a colleague's name, a product, a term from your field — especially when the pronunciation differs from what the model expects. That is what a custom dictionary is for: teach it the word once and it stops coming back misspelled.",
      ],
    },
    {
      heading: "Dictating in more than one language",
      paragraphs: [
        "Most multilingual models are best when they know which language you are about to speak. Auto-detect usually works for a full sentence in one language; switching languages in the middle of a sentence is still hit-and-miss in most tools, so if you do that often, test it before paying for anything. It is also worth checking that the AI cleanup step keeps your text in the language you spoke — Rhino itself had a bug that did this until September 2026, and it is worth testing in whichever tool you pick.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "multilingual dictation with nothing leaving the Mac",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always",
      body: [
        "Mine. For English, Rhino recommends Parakeet v2; for other languages, pick Whisper Large v3 Turbo or Parakeet v3 (multilingual) in Settings, and either set your language or leave it on Auto-detect. Rhino identifies the language on your Mac before the cleanup pass and keeps the cleaned-up text in that language — if the cleanup ever switches languages, the result is thrown away and you keep your original transcript.",
        "The custom dictionary, with sound-alike matching, fixes names and terms the model mishears in your accent. Everything runs on your Mac and works offline. It needs Apple silicon and macOS 14 or later.",
      ],
      url: "/",
    },
    {
      name: "Wispr Flow",
      bestFor: "multilingual dictation on every device",
      price: "$15/month, or $12/month billed annually",
      where: "On Wispr's servers",
      body: [
        "Supports a long list of languages across Mac, Windows and mobile, with strong cleanup. If you need the same multilingual dictation on your phone and your laptop, it is the most complete option. It is cloud-processed and a subscription.",
      ],
      url: "https://wisprflow.ai/",
    },
    {
      name: "Apple Dictation",
      bestFor: "free dictation in the languages Apple supports",
      price: "Free, built into macOS",
      where: "On your Mac for supported languages on Apple silicon; otherwise Apple's servers",
      body: [
        "Supports many languages and dialects, and you can add several and switch between them. On Apple silicon, supported languages run on-device. It transcribes literally, so fillers stay in, and it has no custom vocabulary for names.",
      ],
    },
    {
      name: "superwhisper",
      bestFor: "trying lots of local models for free",
      price: "Free tier; Pro around $8.49/month, with a lifetime option",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      body: [
        "Offers a wide choice of local and cloud models and custom modes, including modes that translate. If you want to experiment with which model handles your languages best, it is the most flexible place to do it.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "MacWhisper",
      bestFor: "transcribing recordings in other languages",
      price: "Free tier; Pro is a one-time licence, around €59 on Gumroad",
      where: "On your Mac",
      body: [
        "For audio files — interviews, meetings, lectures — in dozens of languages, transcribed locally. Useful alongside a dictation app rather than instead of one.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
  ],
  faq: [
    {
      question: "Will dictation understand my accent?",
      answer:
        "Modern Whisper-family models handle a wide range of accents without training, so accuracy is much better than older dictation software. Names and specialist terms are the usual weak spot; a custom dictionary fixes them.",
    },
    {
      question: "Which languages does Rhino Voice support?",
      answer:
        "Rhino ships multilingual models — Whisper Large v3 Turbo and Parakeet v3 — alongside the English-optimised Parakeet v2. Whisper covers a wide range of languages; Parakeet v3 covers major European languages. Set your language or use Auto-detect.",
    },
    {
      question: "Can I switch languages in the middle of a sentence?",
      answer:
        "Mid-sentence switching is still unreliable in most dictation tools, including Rhino. Dictating each sentence or message in one language works much better.",
    },
    {
      question: "Will AI cleanup translate my words into English?",
      answer:
        "It should not, and in Rhino it cannot: the cleanup pass is pinned to the language you spoke, and any cleaned-up result that comes back in a different language is discarded in favour of your original transcript.",
    },
  ],
  ctaBody:
    "$20 once, multilingual models that run on your Mac, and a dictionary for the names your accent trips up. If it does not earn its keep, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Non-Native English Speakers on Mac (2026)",
  description:
    "Accents, multilingual dictation and AI cleanup that stays in your language. Five Mac dictation apps compared honestly by a competitor.",
  alternates: {
    canonical: "https://rhinovoice.app/best/dictation-app-for-non-native-english-speakers",
  },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-non-native-english-speakers",
    title: "Best Dictation App for Non-Native English Speakers on Mac (2026)",
    description: "Accents are no longer the barrier. What matters now for multilingual dictation.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
