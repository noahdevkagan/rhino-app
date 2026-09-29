import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-journalists",
  label: "Best dictation app for journalists",
  headline: "The best dictation and transcription apps for journalists on Mac (2026)",
  dek: "Journalists need two tools: one to transcribe interviews, one to write faster. And if you're protecting a source, where the audio goes matters more than any feature. I make one of these apps. It's a writing tool, not a transcription tool, and it's not my top pick here.",
  shortAnswer:
    "For transcribing interviews, use a file transcription app. If the source is sensitive, use one that runs on your Mac so the recording never hits a server. For writing up (drafts, notes, pitches), a hold-a-key dictation app is faster than typing. MacWhisper is the best local transcription app on Mac. Cloud services like Otter are convenient but keep your recordings.",
  shortPicks: [
    { label: "Best for transcribing interviews locally", pick: "MacWhisper" },
    { label: "Best free local transcription", pick: "Aiko" },
    { label: "Best for drafting copy by voice", pick: "Rhino Voice. On-device, $20 once (mine)" },
    { label: "Best for live meeting transcription (cloud)", pick: "Otter.ai" },
  ],
  intro: [
    {
      heading: "Protecting sources is a transcription question",
      paragraphs: [
        "A recorded interview with a confidential source is one of the most sensitive files you have. Upload it to a cloud transcription service and a copy now lives on someone else's servers, under their retention policy, their security, and the legal system of wherever they operate.",
        "For routine interviews, that's usually fine. For sensitive ones, local transcription kills the question. The audio never leaves your laptop. On a modern Mac, local transcription is fast and accurate enough that you give up very little.",
      ],
    },
    {
      heading: "Writing it up is a dictation question",
      paragraphs: [
        "Once the interview's transcribed, the real work is writing: ledes, drafts, notes to your editor, pitches. That's a different tool. A dictation app lets you talk a rough draft or quick note into whatever you're writing in, with the filler removed. That's where most of the time savings are for working reporters.",
      ],
    },
  ],
  picks: [
    {
      name: "MacWhisper",
      bestFor: "transcribing interviews on your own Mac",
      price: "Free tier; Pro is about €59 once on Gumroad",
      where: "On your Mac",
      local: "Yes",
      body: [
        "The best local transcription app on Mac. Drop in the recording, get a transcript you can search and quote from, and the audio never leaves your machine. Pro adds speaker labels, batch jobs and subtitle export, and it's a one-time purchase. This is my top pick for this page, and it's not mine.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
    {
      name: "Aiko",
      bestFor: "free local transcription, no frills",
      price: "Free",
      where: "On your Mac",
      local: "Yes",
      body: [
        "A free Whisper-based transcription app for Mac and iPhone by Sindre Sorhus. Fewer features than MacWhisper (no speaker labels), but it runs locally and costs nothing. Smart default for a newsroom on a budget.",
      ],
      url: "https://sindresorhus.com/aiko",
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "drafting copy and notes by voice, on your Mac",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. Rhino is for writing, not interview transcription. Hold Fn, talk, let go, and clean text lands in your CMS, Google Docs, Slack or email. It removes filler words and false starts, so a spoken paragraph comes out close to usable copy. Nothing is sent anywhere and it works offline, which is handy on the road.",
        "The custom dictionary keeps names, places and organizations on your beat spelled right. Rhino can transcribe a file you drop in, but for multi-person interviews, MacWhisper is the better tool. Apple silicon and macOS 14 or newer only.",
      ],
      url: "/",
    },
    {
      name: "Otter.ai",
      bestFor: "live transcription of calls and press conferences",
      price: "Free tier with monthly limits; paid plans monthly",
      where: "In Otter's cloud",
      local: "No",
      body: [
        "Convenient, collaborative, and good at live transcription of meetings and calls, with a free tier to start. It's a cloud service that stores your recordings and transcripts. Treat it as a no for sensitive sources unless your organization has signed off on it.",
      ],
      url: "https://otter.ai/",
    },
    {
      name: "Wispr Flow",
      bestFor: "cloud dictation on every device",
      price: "$15/month, or $12/month billed yearly",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "Polished dictation on Mac, Windows and phone, handy for filing from your phone. Cloud and a subscription. Fine for general copy, less fine for notes that name a confidential source.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  verdict: [
    "For interviews: MacWhisper. Start on the free tier. If you're on a tight budget, Aiko. Keep sensitive audio off the cloud, period.",
    "For writing up: once the transcript's done, try talking your first draft instead of typing it. That's what Rhino's for.",
  ],
  today: [
    "Download MacWhisper's free tier and run your last interview recording through it. Time how long it takes.",
    "Look at what transcription service your newsroom uses now, and ask where the audio is stored.",
    "Next time you're stuck on a lede, say it out loud three different ways before you type anything.",
    "If talking your drafts works, try Rhino for a week. Refund if it doesn't save you time.",
  ],
  faq: [
    {
      question: "Is it safe to upload source interviews to a transcription service?",
      answer:
        "Depends on the source and the service. A cloud service keeps a copy of the audio on its servers under its own policies. For sensitive interviews, local apps like MacWhisper or Aiko keep the recording on your Mac.",
    },
    {
      question: "What's the difference between transcription and dictation?",
      answer:
        "Transcription turns an existing recording into text. Dictation types what you say, as you say it, into whatever you're writing. Journalists usually need both.",
    },
    {
      question: "Can Rhino Voice transcribe my interview recordings?",
      answer:
        "It can transcribe a file you drop in, but it doesn't do speaker labels or batch jobs. For interviews, MacWhisper is better. Rhino is built for writing up.",
    },
    {
      question: "Do local transcription apps work offline?",
      answer:
        "Yes. MacWhisper, Aiko and Rhino Voice all run on your Mac and work without internet once their models are downloaded.",
    },
  ],
  ctaBody:
    "$20 once for a dictation app that keeps your notes on your Mac and works on the road. Try it for 30 days. If it doesn't save you time, email me and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation and Transcription Apps for Journalists on Mac (2026)",
  description:
    "Local transcription to protect sources, and dictation for writing up. Five Mac tools, including MacWhisper, Aiko and Otter, from someone who makes one of them.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-journalists" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-journalists",
    title: "Best Dictation and Transcription Apps for Journalists on Mac (2026)",
    description: "Where the interview audio goes matters more than any feature.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
