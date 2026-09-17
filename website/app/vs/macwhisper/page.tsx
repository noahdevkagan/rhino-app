import type { Metadata } from "next";
import { ComparisonPage, type ComparisonContent } from "../../_components/comparison-page";

const content: ComparisonContent = {
  slug: "/vs/macwhisper",
  competitor: "MacWhisper",
  headline: "Rhino Voice vs MacWhisper (2026): transcribing a file vs typing with your voice",
  dek: "These two get compared constantly and they are not really competitors. One turns recordings you already have into text; the other turns your voice into text as you speak. Here is how to tell which problem you actually have.",
  shortAnswer:
    "MacWhisper is a file transcription app: you give it an audio or video file, a meeting recording or a YouTube URL, and it gives you back a transcript with speaker labels and subtitle exports. Rhino Voice is a dictation app: you hold a key, talk, and polished text appears in whatever app your cursor is in. Both run locally on your Mac, and plenty of people should own both.",
  pickThem:
    "your job is turning recordings into transcripts — interviews, podcasts, lecture recordings, footage you need subtitles for.",
  pickRhino:
    "your job is writing, and typing is the bottleneck — email, Slack, docs, code comments, prompts to an AI assistant.",
  tableCaption: "Rhino vs MacWhisper at a glance",
  checked: "September 2026",
  rows: [
    { label: "Primary job", rhino: "Live dictation into any app", them: "Transcribing existing audio and video files" },
    { label: "Price", rhino: "$20 once", them: "Free tier; Pro is a one-time licence, around €59 on Gumroad" },
    { label: "Runs locally", rhino: "Yes, always", them: "Yes" },
    { label: "Hold-a-key dictation anywhere", rhino: "The whole point of the app", them: "Included on the Gumroad version, but not its focus" },
    { label: "AI cleanup of dictated text", rhino: "Yes, from a local model", them: "Not the same live cleanup flow" },
    { label: "Transcribe a file you already have", rhino: "Yes — drop it in, or use the command line", them: "Yes, and far more thoroughly" },
    { label: "Speaker labels, subtitles, batch jobs", rhino: "No", them: "Yes, on Pro" },
    { label: "Custom vocabulary", rhino: "Yes, stored locally", them: "Yes" },
    { label: "Platforms", rhino: "macOS 14+ on Apple silicon only", them: "macOS" },
  ],
  sections: [
    {
      heading: "They solve different problems",
      paragraphs: [
        "MacWhisper is excellent and I recommend it without hesitation for what it is built for. If you have a folder of interview recordings, a podcast episode that needs a transcript, or a video that needs subtitles burned into an SRT file, MacWhisper Pro will chew through it with speaker diarization and batch processing and hand you exactly what you asked for.",
        "Rhino cannot do any of that well. It will transcribe a file you drop on it, but there is no diarization, no subtitle export and no batch queue, and I have no plans to add them.",
        "What Rhino does instead is take over the act of writing. You are in Slack or an email or a document, you hold Fn, you say the thing, you let go, and the sentence is there — punctuated, capitalised, with your \"ums\" removed. There is no file, no import step and no window to switch to. That is a different activity from transcription, even though both end in text.",
      ],
    },
    {
      heading: "The overlap, honestly",
      paragraphs: [
        "MacWhisper's Gumroad version does include system-wide dictation, and it works. If you bought it for file transcription and you also want to dictate occasionally, you may not need a second app at all — try what you already own before you spend anything.",
        "Where a dedicated dictation app earns its place is in the details that only matter when you dictate all day: a cleanup pass tuned for spoken language rather than recorded audio, a custom dictionary that boosts recognition of names you say constantly, verbatim pass-through when you are talking to an AI assistant or a terminal, and a long-recording guard so a forgotten session does not paste a wall of text into whatever window happened to be focused. Those are the things Rhino spends its whole surface area on.",
      ],
    },
    {
      heading: "On price",
      paragraphs: [
        "Both are one-time purchases, which is increasingly rare and worth rewarding in both cases. MacWhisper Pro runs around €59 on Gumroad with a free tier underneath it; the Mac App Store edition is sold on a separate subscription-and-lifetime structure, so check which one you are buying. Rhino is $20 once with a 30-day money-back guarantee.",
        "If you need both jobs done, owning both still costs less than a single year of most cloud dictation subscriptions.",
      ],
    },
  ],
  faq: [
    {
      question: "Can MacWhisper do live dictation?",
      answer:
        "Yes — the Gumroad version includes system-wide dictation. It is not the product's focus, though; MacWhisper is built and marketed around transcribing audio and video files, with features like batch processing, speaker diarization and subtitle export that a dictation app has no use for.",
    },
    {
      question: "Can Rhino Voice transcribe an audio file?",
      answer:
        "Yes. You can drop a file onto Rhino or transcribe it from the command line, and you can re-run a saved recording through a different local model. What it does not do is speaker labels, subtitle formats or batch queues — for those, use MacWhisper.",
    },
    {
      question: "Do both run offline?",
      answer:
        "Yes. Both transcribe locally on your Mac using Whisper-family models, so neither requires a connection once its models are downloaded.",
    },
    {
      question: "Which is better value?",
      answer:
        "They are priced for different jobs, and both are one-time purchases rather than subscriptions. Buy the one that matches the work you do most; if you genuinely do both jobs, owning both is still cheaper than a year of a cloud dictation subscription.",
    },
    {
      question: "What are Rhino's system requirements?",
      answer:
        "An Apple silicon Mac running macOS 14 or later. Intel Macs are not supported.",
    },
  ],
};

export const metadata: Metadata = {
  title: "Rhino Voice vs MacWhisper (2026): Dictation vs File Transcription on Mac",
  description:
    "MacWhisper transcribes recordings you already have. Rhino Voice types your voice into any app as you speak. Both run locally on your Mac — here's which problem each one solves.",
  alternates: { canonical: "https://rhinovoice.app/vs/macwhisper" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/vs/macwhisper",
    title: "Rhino Voice vs MacWhisper (2026): Dictation vs File Transcription on Mac",
    description:
      "Constantly compared, rarely competitors. How to tell which problem you actually have.",
  },
};

export default function Page() {
  return <ComparisonPage content={content} />;
}
