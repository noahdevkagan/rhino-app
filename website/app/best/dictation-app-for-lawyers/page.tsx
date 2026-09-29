import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-lawyers",
  label: "Best dictation app for lawyers",
  headline: "The best dictation app for lawyers on a Mac (2026)",
  dek: "Lawyers were Dragon's best customers, and most of them have been improvising since it left the Mac. I build one of the apps below, so weigh this accordingly — but the question that decides it for a law practice is not accuracy any more. It is where the words go.",
  shortAnswer:
    "For a lawyer, the deciding question is whether privileged material leaves the machine. Modern on-device dictation is accurate enough for memos, letters and client email, so pick a tool that transcribes on your Mac and needs no vendor agreement at all. Cloud tools can be fine, but they make dictation a vendor-risk decision your firm has to sign off on.",
  shortPicks: [
    { label: "Best overall for privileged work", pick: "Rhino Voice — on-device only, $20 once (mine)" },
    { label: "Best free option", pick: "Apple Dictation, with on-device dictation enabled" },
    { label: "Best for transcribing recorded memos", pick: "MacWhisper" },
    { label: "Best if your firm is standardised on Windows", pick: "Dragon Legal" },
  ],
  intro: [
    {
      heading: "Why privilege changes the answer",
      paragraphs: [
        "Most dictation apps sold today send your audio to a server, turn it into text there, and send the text back. For a sales email that is irrelevant. For a draft settlement position, a note on a client's exposure, or an email about a matter that is not public yet, it means a copy of privileged content has passed through a third party. Whether that is acceptable is a question for your firm's policies and your jurisdiction's ethics guidance, and the honest answer is that plenty of firms do allow it with the right contracts in place.",
        "The simpler answer is to avoid the question. If transcription happens on your own Mac and nothing is transmitted, there is no vendor holding your audio, no data processing agreement to negotiate, and nothing for an IT review to find. On Apple silicon, local speech recognition is now good enough that you give up very little to get that.",
      ],
    },
    {
      heading: "What lawyers actually dictate",
      paragraphs: [
        "Three jobs, and they want different tools. Live drafting — letters, memos, email, file notes — is the bulk of it, and that is what a hold-a-key dictation app is for. Transcribing recordings — a memo you dictated into your phone in the car, a client interview you recorded with permission — is a file job, and a transcription app does it better. Formal records of depositions and hearings are neither: those remain the court reporter's job, and none of the software here produces a certified transcript.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "privileged drafting where nothing may leave the machine",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always — there is no cloud option in the app",
      body: [
        "This is mine. I built it so that the privacy question has one answer: speech recognition and the AI cleanup pass both run on your Mac, there is no account, and it works with Wi-Fi off. Hold Fn, dictate the paragraph, release, and cleaned-up text lands in Word, Outlook, your practice management system or a browser box — punctuated, with the ums and false starts removed.",
        "The custom dictionary is where it earns its keep in a legal practice. Add client names, opposing counsel, case names and the Latin you actually use, and Rhino both corrects the spelling and fixes near-miss hearings of it. Dictation history stays on your Mac, and you can set a retention limit or switch history off so nothing is kept at all.",
        "What it is not: it does not operate your computer by voice, and it needs an Apple silicon Mac on macOS 14 or later. If your firm runs Windows, it is not an option.",
      ],
      url: "/",
    },
    {
      name: "Apple Dictation",
      bestFor: "finding out whether you need to pay anyone",
      price: "Free, built into macOS",
      where: "On your Mac, on Apple silicon with on-device dictation enabled",
      body: [
        "Already installed and, on an Apple silicon Mac, processed on the device for supported languages. Press the dictation shortcut and talk. For short replies and file notes it is perfectly serviceable, and it costs nothing to find out.",
        "Its limit is that it transcribes you literally. Every \"um\", restart and \"sorry, strike that\" lands in the document, so longer dictation needs a real editing pass afterwards — and for many lawyers that editing pass is where the time savings go.",
      ],
    },
    {
      name: "MacWhisper",
      bestFor: "transcribing memos and interviews you recorded",
      price: "Free tier; Pro is a one-time licence, around €59 on Gumroad",
      where: "On your Mac",
      body: [
        "If your habit is dictating into a phone on the move and dealing with it later, you want a file transcription app, and MacWhisper is the best one on the Mac. It runs locally, handles long recordings, and on Pro adds speaker labels and batch jobs — useful for a recorded client interview where you need to know who said what.",
        "The Gumroad version also includes system-wide dictation, so some lawyers find one purchase covers both jobs.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
    {
      name: "superwhisper",
      bestFor: "a free local tier with lots of configuration",
      price: "Free tier; Pro around $8.49/month, with a lifetime option",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      body: [
        "A capable Mac dictation app whose free tier runs local models, so it is a zero-cost way to try modern dictation on privileged material. The paid tier adds custom modes and prompts — you can build a mode that formats a dictated letter a particular way.",
        "The caution for a firm is that it also offers cloud models. That is a feature for most users; for a practice with a no-cloud policy it means relying on every lawyer to keep the right model selected.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "Dragon Legal, on Windows",
      bestFor: "firms already standardised on Dragon and Windows",
      price: "One-time Windows licence, several hundred dollars",
      where: "On the Windows machine running it",
      body: [
        "Dragon Legal is still sold for Windows, with a legal vocabulary that had decades of tuning and a macro system firms built whole workflows around. If your firm has those workflows, a Mac dictation app will not replace them and you should not pretend otherwise.",
        "On a Mac it means running Windows in a virtual machine or keeping a PC on the desk, which is a project rather than an afternoon.",
      ],
    },
    {
      name: "Wispr Flow",
      bestFor: "firms that have approved a cloud vendor and want polish",
      price: "$15/month, or $12/month billed annually",
      where: "On Wispr's servers",
      body: [
        "The most polished cloud dictation product, and it runs on Mac, Windows and mobile. It holds SOC 2 Type II and ISO 27001 certifications, which is the paperwork a firm's vendor review will ask for.",
        "It is still a cloud service: your dictation is processed on their servers. If your firm has reviewed and approved that, it is a very good product. If nobody has asked the question yet, ask it before you dictate a client matter into it.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  faq: [
    {
      question: "Is it safe for a lawyer to use cloud dictation?",
      answer:
        "It can be, with the right vendor agreements and your firm's approval — many firms allow it. But cloud dictation sends privileged content to a third party, so it is a vendor-risk decision. On-device dictation, where nothing is transmitted, avoids the question entirely. Check your firm's policy and your jurisdiction's ethics guidance.",
    },
    {
      question: "Does Rhino Voice send anything to a server?",
      answer:
        "No. Audio, transcripts, history and the AI cleanup pass all stay on your Mac. Rhino only reaches the network to check for signed app updates and to download speech models you explicitly ask for, and dictation works with Wi-Fi off.",
    },
    {
      question: "Can dictation software produce a deposition transcript?",
      answer:
        "Not a certified one. Transcription apps like MacWhisper can turn a recording into a working transcript with speaker labels, which is useful for your own review, but the official record of a deposition or hearing is still produced by a court reporter.",
    },
    {
      question: "Will it get case names and legal terms right?",
      answer:
        "General speech models handle ordinary legal English well. Names — clients, parties, cases — are where they slip. A custom dictionary fixes that: add the terms once and the app corrects them every time. Rhino, superwhisper, VoiceInk and MacWhisper all have one.",
    },
    {
      question: "Does any of this work on Windows?",
      answer:
        "Dragon Legal and Wispr Flow do. Rhino Voice, superwhisper and MacWhisper are Mac-only, and Rhino specifically needs an Apple silicon Mac on macOS 14 or later.",
    },
  ],
  ctaBody:
    "$20 once, no subscription, no account, and nothing leaves your Mac — so there is no vendor to review. If it does not earn its keep, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Lawyers on Mac (2026): Privilege-Safe Options",
  description:
    "For lawyers, the question is where privileged dictation goes. Six Mac options compared by a competitor — on-device, cloud and Dragon Legal — with the trade-offs stated plainly.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-lawyers" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-lawyers",
    title: "Best Dictation App for Lawyers on Mac (2026)",
    description: "Accuracy is solved. The deciding question is whether privileged words leave the machine.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
