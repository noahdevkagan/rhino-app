import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-non-native-english-speakers",
  label: "Best dictation app for non-native English speakers",
  headline: "The best dictation app for non-native English speakers on Mac (2026)",
  dek: "Old dictation software was trained on a narrow set of accents and made everyone else repeat themselves. That's mostly over. I make one of the apps below, so I'm biased, but here's what actually matters if English is your second language or you dictate in more than one.",
  shortAnswer:
    "Modern Whisper-style speech models handle a wide range of accents without any voice training, so your accent is much less of a problem than it used to be. If you dictate in English with an accent, pick an app with AI cleanup and a custom dictionary. If you dictate in several languages, pick one with a multilingual model that lets you set or auto-detect the language, and test switching languages mid-sentence before you rely on it.",
  shortPicks: [
    { label: "Best on-device multilingual dictation", pick: "Rhino Voice. Whisper Large v3 Turbo or Parakeet v3 on your Mac, $20 once (mine)" },
    { label: "Best cloud option on every device", pick: "Wispr Flow" },
    { label: "Best free option", pick: "Apple Dictation" },
    { label: "Best free local app with lots of models", pick: "superwhisper" },
  ],
  intro: [
    {
      heading: "Your accent isn't the problem anymore",
      paragraphs: [
        "Whisper and the models after it were trained on huge amounts of speech from all over the world. No voice training needed. A clear speaker with a strong accent now gets accurate results out of the box way more often than with the dictation software from ten years ago.",
        "Where it still goes wrong: names and special words. Your coworker's name, your product, a term from your field. Especially when you say it differently than the model expects. That's what a custom dictionary is for. Teach it the word once and it stops coming back wrong.",
      ],
    },
    {
      heading: "Dictating in more than one language",
      paragraphs: [
        "Most multilingual models work best when they know which language is coming. Auto-detect usually nails a full sentence in one language. Switching languages in the middle of a sentence is still hit-and-miss in most tools. If you do that a lot, test it before you pay.",
        "Also check that the AI cleanup keeps your text in the language you spoke. Rhino had a bug that translated to English until September 2026. We fixed it. Test for it in whatever you pick.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "multilingual dictation with nothing leaving your Mac",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. For English, Rhino recommends Parakeet v2. For other languages, pick Whisper Large v3 Turbo or Parakeet v3 (multilingual) in Settings, then set your language or leave it on Auto-detect.",
        "Rhino figures out the language on your Mac before cleanup and keeps the cleaned-up text in that language. If cleanup ever switches languages, Rhino throws that result away and gives you your original transcript.",
        "The custom dictionary also catches words that sound close to the ones you add, which helps with names the model mishears in your accent. Everything runs on your Mac and works offline. Needs Apple silicon and macOS 14 or newer.",
      ],
      url: "/",
    },
    {
      name: "Wispr Flow",
      bestFor: "multilingual dictation on every device",
      price: "$15/month, or $12/month billed yearly",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "Supports a long list of languages on Mac, Windows and phone, with strong cleanup. If you need the same multilingual dictation on your phone and laptop, it's the most complete option. It's cloud and a subscription.",
      ],
      url: "https://wisprflow.ai/",
    },
    {
      name: "Apple Dictation",
      bestFor: "free dictation in the languages Apple supports",
      price: "Free, built into macOS",
      where: "On your Mac for supported languages on Apple silicon; otherwise Apple's servers",
      local: "Mostly",
      body: [
        "Lots of languages and dialects, and you can add several and switch between them. On Apple silicon, supported languages run on-device. It types literally, so filler stays in, and there's no custom vocabulary for names.",
      ],
    },
    {
      name: "superwhisper",
      bestFor: "trying lots of local models for free",
      price: "Free tier; Pro about $8.49/month, lifetime available",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      local: "Optional",
      body: [
        "Tons of local and cloud models plus custom modes, including modes that translate. If you want to experiment with which model handles your languages best, this is the place to do it.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "MacWhisper",
      bestFor: "transcribing recordings in other languages",
      price: "Free tier; Pro is about €59 once on Gumroad",
      where: "On your Mac",
      local: "Yes",
      body: [
        "For audio files like interviews, meetings and lectures in dozens of languages, transcribed on your Mac. Use it next to a dictation app, not instead of one.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
  ],
  verdict: [
    "Don't let your accent stop you from trying dictation. Modern models are good. Try Apple Dictation free and see for yourself.",
    "If you want cleanup that stays in your language and nothing leaving your Mac, try Rhino with Whisper Large v3 Turbo. If you need it on your phone too, Wispr Flow.",
  ],
  today: [
    "Turn on Apple Dictation (System Settings → Keyboard → Dictation) and add every language you use.",
    "Dictate one email in English and one in your other language. Check what came back.",
    "Write down the names and terms it got wrong. That's your custom dictionary.",
    "Try Rhino with those words added for a week. Refund if it's not better.",
  ],
  faq: [
    {
      question: "Will dictation understand my accent?",
      answer:
        "Modern Whisper-style models handle a wide range of accents without training, so accuracy is much better than older dictation software. Names and special terms are the usual weak spot. A custom dictionary fixes them.",
    },
    {
      question: "Which languages does Rhino Voice support?",
      answer:
        "Rhino ships multilingual models, Whisper Large v3 Turbo and Parakeet v3, plus Parakeet v2 for English. Whisper covers a wide range of languages; Parakeet v3 covers major European languages. Set your language or use Auto-detect.",
    },
    {
      question: "Can I switch languages in the middle of a sentence?",
      answer:
        "Switching mid-sentence is still unreliable in most dictation tools, including Rhino. Dictating each sentence or message in one language works much better.",
    },
    {
      question: "Will AI cleanup translate my words into English?",
      answer:
        "It shouldn't, and in Rhino it can't. Cleanup is locked to the language you spoke, and any cleaned-up result that comes back in a different language gets thrown away in favor of your original transcript.",
    },
  ],
  ctaBody:
    "$20 once. Multilingual models that run on your Mac, and a dictionary for the names your accent trips up. Try it for 30 days. If it's not better, email me and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Non-Native English Speakers on Mac (2026)",
  description:
    "Accents, multilingual dictation, and AI cleanup that stays in your language. Five Mac dictation apps compared by someone who makes one of them.",
  alternates: {
    canonical: "https://rhinovoice.app/best/dictation-app-for-non-native-english-speakers",
  },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-non-native-english-speakers",
    title: "Best Dictation App for Non-Native English Speakers on Mac (2026)",
    description: "Your accent isn't the problem anymore. What matters now for multilingual dictation.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
