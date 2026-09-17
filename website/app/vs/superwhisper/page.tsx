import type { Metadata } from "next";
import { ComparisonPage, type ComparisonContent } from "../../_components/comparison-page";

const content: ComparisonContent = {
  slug: "/vs/superwhisper",
  competitor: "superwhisper",
  headline: "Rhino vs superwhisper (2026): the closest competitor Rhino has",
  dek: "Most dictation apps send your voice to a server. superwhisper does not have to, which makes it the one honest comparison I have to work at. Here it is, written by the person who built the competitor.",
  shortAnswer:
    "superwhisper and Rhino both run speech recognition locally on your Mac, so on the privacy question they largely agree. They differ on shape: superwhisper is a free-to-start, deeply configurable app whose paid tier adds optional cloud AI models and runs on Windows and mobile too, while Rhino is one opinionated $20 Mac app with no free tier, no subscription, and no cloud option at all.",
  pickThem:
    "you want to try it for free, you like tuning modes and prompts, you want the option of cloud models for the hard transcripts, or you need Windows and mobile.",
  pickRhino:
    "you want one app with one job and no cloud pathway to audit, a single $20 payment with no plan to reason about, and defaults that are already correct.",
  tableCaption: "Rhino vs superwhisper at a glance",
  checked: "September 2026",
  rows: [
    { label: "Price", rhino: "$20 once, forever", them: "Free tier; Pro around $8.49/month, with a lifetime option" },
    { label: "Local speech recognition", rhino: "Yes — Whisper or Parakeet, on your Mac", them: "Yes — Whisper models, on your Mac" },
    { label: "Cloud models available", rhino: "No. There is no cloud pathway in the app", them: "Yes, on Pro — GPT-5, Claude, Gemini and others" },
    { label: "Works offline", rhino: "Yes, always", them: "Yes, with local models selected" },
    { label: "Account required", rhino: "No", them: "Not for the free local tier" },
    { label: "Platforms", rhino: "macOS 14+ on Apple silicon only", them: "Mac, Windows, iPhone, Android" },
    { label: "Configurability", rhino: "Deliberately small: one flow, sane defaults", them: "Extensive: modes, custom prompts, per-app behaviour" },
    { label: "Verbatim in AI apps and terminals", rhino: "Automatic — cleanup is skipped there by default", them: "Achievable by configuring a mode yourself" },
    { label: "Built by", rhino: "One person (me)", them: "A small independent team" },
  ],
  sections: [
    {
      heading: "Where the two genuinely agree",
      paragraphs: [
        "If your reason for shopping is that you do not want your voice on somebody's server, superwhisper already solves that for you, for free. I would rather tell you that than pretend otherwise. Both apps run Whisper-family models locally on Apple silicon, both work with the network off, and both keep your transcripts on your own disk.",
        "So the privacy argument I would make against a cloud competitor does not apply here, and the comparison comes down to something less dramatic: what shape of app you want to live with.",
      ],
    },
    {
      heading: "superwhisper is the configurable one",
      paragraphs: [
        "It has modes, custom prompts, per-context behaviour, and a growing menu of models — including, on the paid tier, cloud models from the big labs if you want to point a hard transcript at one. It runs on Windows and on your phone. If you enjoy tuning a tool until it fits you exactly, superwhisper gives you far more surface to tune than Rhino does, and the free tier means you can find that out at no cost.",
        "That breadth has a cost that is worth naming: an app that can use cloud models has a cloud pathway in it. It is opt-in and clearly labelled, and plenty of people want it there. But if your bar is \"I want to be able to say that this software cannot transmit my audio, full stop,\" a configurable option is a weaker guarantee than an absent one.",
      ],
    },
    {
      heading: "Rhino is the opinionated one",
      paragraphs: [
        "Rhino does one thing: hold Fn, talk, release, get clean text in the app you were already in. There are no modes to pick, and the defaults are the settings I would have told you to choose. There is no cloud option to audit, because there is no code in Rhino that sends audio anywhere.",
        "A few of those opinions are load-bearing. Dictate into Claude, ChatGPT or a terminal and Rhino automatically skips its AI cleanup, so an instruction meant for the assistant arrives verbatim instead of being tidied into prose. Recordings over five minutes go to your clipboard with a note instead of pasting themselves into whatever happened to be focused. You can configure both, but you should not have to.",
        "And it is $20 once. Not a free tier that you will eventually outgrow into a subscription — one payment, every feature, forever.",
      ],
    },
    {
      heading: "The honest recommendation",
      paragraphs: [
        "Try superwhisper's free tier first. It costs nothing, it runs locally, and it will teach you whether hold-to-talk dictation belongs in your day at all — which is the question that actually matters, and the one neither of us can answer for you.",
        "If it sticks and you find yourself either reaching for the paid tier or wishing the app would stop asking you to configure it, that is the moment Rhino makes sense: one price, one flow, no cloud pathway, done.",
      ],
    },
  ],
  faq: [
    {
      question: "Is superwhisper private?",
      answer:
        "With local models selected, yes — it transcribes on your Mac and works offline, the same as Rhino. The distinction is that superwhisper's paid tier can also route transcription or cleanup to cloud models from providers like OpenAI, Anthropic and Google if you choose to enable them. Rhino has no such option.",
    },
    {
      question: "Is Rhino cheaper than superwhisper?",
      answer:
        "It depends which superwhisper you compare against. Its free tier is free, and Rhino cannot beat that. Against superwhisper Pro at roughly $8.49 a month, Rhino's single $20 payment pays for itself inside three months.",
    },
    {
      question: "Which one is more accurate?",
      answer:
        "They run the same family of open speech models on the same hardware, so raw transcription accuracy is close enough that the difference in practice comes from the cleanup pass and your custom vocabulary rather than the recogniser. Test both on your own voice and your own jargon — that is the only benchmark that predicts your experience.",
    },
    {
      question: "Does Rhino have a free trial?",
      answer:
        "No free tier, but there is a 30-day money-back guarantee. Buy it, use it properly for a month, and if it has not earned its keep, email me for a refund.",
    },
    {
      question: "Can I run Rhino on an Intel Mac or on Windows?",
      answer:
        "No. Rhino requires an Apple silicon Mac running macOS 14 or later. If you need Windows or mobile, superwhisper covers those and Rhino does not.",
    },
  ],
};

export const metadata: Metadata = {
  title: "Rhino vs superwhisper (2026): Two Local Mac Dictation Apps Compared",
  description:
    "Both run speech recognition on your Mac. superwhisper is free-to-start and highly configurable with optional cloud models; Rhino is $20 once with no cloud pathway. Honest comparison from Rhino's founder.",
  alternates: { canonical: "https://rhinovoice.app/vs/superwhisper" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/vs/superwhisper",
    title: "Rhino vs superwhisper (2026): Two Local Mac Dictation Apps Compared",
    description:
      "The closest competitor Rhino has. Where they agree on privacy, and where they genuinely differ.",
  },
};

export default function Page() {
  return <ComparisonPage content={content} />;
}
