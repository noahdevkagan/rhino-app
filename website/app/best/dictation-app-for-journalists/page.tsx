import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-journalists",
  label: "Best dictation app for journalists",
  headline: "The best dictation and transcription apps for journalists on a Mac (2026)",
  dek: "Journalists need two tools: one to transcribe interviews, one to write faster. And for anyone protecting a source, where the audio goes matters more than any feature. I make one of the apps below — a writing tool, not a transcription one — so here is the honest split.",
  shortAnswer:
    "For transcribing interviews, use a file transcription app; if the source is sensitive, use one that runs on your Mac so the recording never goes to a server. For writing up — drafting copy, notes and pitches — a hold-a-key dictation app is faster than typing. MacWhisper is the strongest local transcription app on the Mac; cloud services like Otter are convenient but hold your recordings.",
  shortPicks: [
    { label: "Best for transcribing interviews locally", pick: "MacWhisper" },
    { label: "Best free local transcription", pick: "Aiko" },
    { label: "Best for drafting copy by voice", pick: "Rhino Voice — on-device, $20 once (mine)" },
    { label: "Best for live meeting transcription in the cloud", pick: "Otter.ai" },
  ],
  intro: [
    {
      heading: "Source protection is a transcription question",
      paragraphs: [
        "A recorded interview with a confidential source is one of the most sensitive files a journalist holds. Uploading it to a cloud transcription service means a copy exists on someone else's infrastructure, subject to their retention policy, their security and the legal process of wherever they operate. For routine interviews that is often fine. For sensitive ones, local transcription removes the question — the audio never leaves your laptop.",
        "Local transcription on Apple silicon is now fast and accurate enough that you give up little by doing it. Speaker labels and timestamps are available locally too.",
      ],
    },
    {
      heading: "Writing up is a dictation question",
      paragraphs: [
        "Once the interview is transcribed, the work is writing: ledes, drafts, notes to your editor, pitches. That is a different tool. A dictation app lets you talk a rough draft or a quick note into whatever you are writing in, with filler words removed, and it is where most of the time savings for working reporters actually are.",
      ],
    },
  ],
  picks: [
    {
      name: "MacWhisper",
      bestFor: "transcribing interviews on your own Mac",
      price: "Free tier; Pro is a one-time licence, around €59 on Gumroad",
      where: "On your Mac",
      body: [
        "The strongest local transcription app on the Mac. Drop in the recording and get a transcript you can search and quote from, without the audio leaving your machine. Pro adds speaker labels, batch processing and subtitle export, and it is a one-time purchase.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
    {
      name: "Aiko",
      bestFor: "free local transcription with no frills",
      price: "Free",
      where: "On your Mac",
      body: [
        "A free Whisper-based transcription app for Mac and iPhone from Sindre Sorhus. Fewer features than MacWhisper — no speaker labels — but it runs locally and costs nothing, which makes it a sensible default for a newsroom on a budget.",
      ],
      url: "https://sindresorhus.com/aiko",
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "drafting copy and notes by voice, on-device",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always",
      body: [
        "Mine. Rhino is for writing, not interview transcription: hold Fn, talk, release, and cleaned-up text lands at your cursor in your CMS, Google Docs, Slack or email. It removes filler words and false starts, so a spoken paragraph comes out close to usable copy. Nothing is transmitted and it works offline — useful on the road.",
        "The custom dictionary keeps names, places and organisations you are covering spelled right. Rhino can also transcribe a dropped-in file, but for interviews with multiple speakers MacWhisper is the better tool. Apple silicon and macOS 14 or later only.",
      ],
      url: "/",
    },
    {
      name: "Otter.ai",
      bestFor: "live transcription of calls and press conferences",
      price: "Free tier with monthly limits; paid plans monthly",
      where: "In Otter's cloud",
      body: [
        "Convenient, collaborative, and good at live transcription of meetings and calls, with a free tier to start. It is a cloud service that stores your recordings and transcripts, so treat it as unsuitable for sensitive sources unless your organisation has assessed it.",
      ],
      url: "https://otter.ai/",
    },
    {
      name: "Wispr Flow",
      bestFor: "cloud dictation on every device",
      price: "$15/month, or $12/month billed annually",
      where: "On Wispr's servers",
      body: [
        "Polished dictation on Mac, Windows and mobile, handy for filing from a phone. Cloud-processed and a subscription; fine for general copy, less so for notes that name a confidential source.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  faq: [
    {
      question: "Is it safe to upload source interviews to a transcription service?",
      answer:
        "It depends on the source and the service. A cloud service keeps a copy of the audio on its infrastructure under its own policies. For sensitive interviews, local transcription apps like MacWhisper or Aiko keep the recording on your Mac.",
    },
    {
      question: "What is the difference between transcription and dictation?",
      answer:
        "Transcription turns an existing recording into text. Dictation types what you say, as you say it, into whatever you are writing. Journalists usually need both.",
    },
    {
      question: "Can Rhino Voice transcribe my interview recordings?",
      answer:
        "It can transcribe a dropped-in file, but it has no speaker labels or batch jobs. For interviews, MacWhisper is the better tool; Rhino is built for writing up.",
    },
    {
      question: "Do local transcription apps work offline?",
      answer:
        "Yes. MacWhisper, Aiko and Rhino Voice all run on your Mac and work without a connection once their models are downloaded.",
    },
  ],
  ctaBody:
    "$20 once for a dictation app that keeps your notes on your Mac and works on the road. If it does not earn its keep, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation and Transcription Apps for Journalists on Mac (2026)",
  description:
    "Local transcription for protecting sources, and dictation for writing up. Five Mac tools compared honestly by a competitor — MacWhisper, Aiko, Otter and more.",
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
