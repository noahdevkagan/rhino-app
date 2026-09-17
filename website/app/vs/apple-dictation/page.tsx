import type { Metadata } from "next";
import { ComparisonPage, type ComparisonContent } from "../../_components/comparison-page";

const content: ComparisonContent = {
  slug: "/vs/apple-dictation",
  competitor: "Apple Dictation",
  headline: "Rhino vs Apple Dictation (2026): is the free one already good enough?",
  dek: "macOS has had built-in dictation for years, it runs on-device, and it costs nothing. Here is the honest case for when that is all you need — and the specific things it does not do.",
  shortAnswer:
    "Apple Dictation is free, built into macOS, and on Apple silicon it runs on-device, so it already solves the privacy problem. What it does not do is clean up how people actually talk: it transcribes you literally, leaving your filler words, false starts and spoken-aloud punctuation in the text. Rhino adds a local AI cleanup pass that turns a rambling sentence into the one you meant to write.",
  pickThem:
    "you dictate occasionally, you speak in clean finished sentences, and free-and-already-installed beats everything else.",
  pickRhino:
    "you dictate all day, you think out loud with false starts and \"ums\", and you are tired of editing the transcript into a sentence you could have typed.",
  tableCaption: "Rhino vs Apple Dictation at a glance",
  checked: "September 2026",
  rows: [
    { label: "Price", rhino: "$20 once", them: "Free, built into macOS" },
    { label: "Runs on-device", rhino: "Yes, always", them: "Yes on Apple silicon, with on-device dictation enabled" },
    { label: "Removes filler words and false starts", rhino: "Yes — that is the cleanup pass", them: "No, it transcribes you literally" },
    { label: "Punctuation", rhino: "Inferred for you from how you spoke", them: "Auto-punctuation for commas, periods and question marks; the rest you say aloud" },
    { label: "Formatting and structure", rhino: "Cleanup handles casing, lists and paragraphing", them: "You speak it, or you fix it afterwards" },
    { label: "Custom vocabulary for names and jargon", rhino: "Yes, with recognition boosting", them: "Limited" },
    { label: "Local history, search and stats", rhino: "Yes, and you can turn it off", them: "No" },
    { label: "Verbatim mode in AI apps and terminals", rhino: "Automatic", them: "Always verbatim — that is all it does" },
    { label: "Requirements", rhino: "Apple silicon Mac, macOS 14+", them: "Any supported Mac" },
  ],
  sections: [
    {
      heading: "Start with the free one. Seriously.",
      paragraphs: [
        "Apple Dictation is already on your Mac. Turn it on in System Settings, enable on-device dictation, and press the shortcut. If that covers what you need, you have just saved twenty dollars and I would rather you did that than bought something you do not need.",
        "A lot of people never get past the first week, though, and the reason is consistent. Apple Dictation transcribes what you said. Not what you meant — what you actually said, ums and restarts and all.",
      ],
    },
    {
      heading: "The gap is cleanup, not accuracy",
      paragraphs: [
        "Modern speech recognition is good. Apple's recogniser will usually get your words right, and so will Rhino's. The problem is that nobody speaks in finished prose. You say \"so I think we should, um, actually let's move the kickoff — move it to four\" and a literal transcriber writes exactly that down.",
        "Rhino runs a second pass over the raw transcript with a language model on your Mac. That pass drops the filler, resolves the false start, works out that \"move it to four\" is the sentence you actually wanted, and applies casing and punctuation you never had to say aloud. What lands at your cursor is a line you can send.",
        "That is the whole difference, and it is worth twenty dollars or it is not, depending entirely on how much you dictate.",
      ],
    },
    {
      heading: "The smaller things that add up",
      paragraphs: [
        "Names are the other daily friction. Apple Dictation has no meaningful way to be taught that your colleague is spelled Kagan, or that your product is called Rhino rather than \"rhyno\". Rhino's custom dictionary both replaces text and boosts recognition of the terms you added, so the words you say fifty times a day stop coming back wrong.",
        "Then there is the behaviour around edges: a local history you can search, re-run or switch off entirely; a guard that copies very long recordings to the clipboard instead of pasting them somewhere unexpected; and automatic verbatim pass-through when you are dictating into Claude, ChatGPT or a terminal, so an instruction meant for the assistant is not smoothed into prose before it arrives.",
      ],
    },
    {
      heading: "What Apple Dictation is better at",
      paragraphs: [
        "It is free, it is already installed, and it runs on every supported Mac including Intel machines, where Rhino does not run at all. It needs no model download and no permissions dance beyond the microphone. It supports a long list of languages maintained by a company with Apple's resources.",
        "And because it is literal, it is predictable. If your work is dictating exact strings — codes, commands, quoted text — a cleanup pass is an active nuisance, and the free tool is the right tool. Rhino's answer is to detect those contexts and disable cleanup, but Apple's answer of never having it in the first place is simpler.",
      ],
    },
  ],
  faq: [
    {
      question: "Does Apple Dictation send my voice to Apple?",
      answer:
        "Not if you are on an Apple silicon Mac with on-device dictation enabled — in that configuration speech recognition happens locally. That is why privacy alone is not a good reason to leave it; the reason to leave it is that it transcribes you literally.",
    },
    {
      question: "Is there a time limit on Apple Dictation?",
      answer:
        "On-device dictation on Apple silicon removed the old short cut-off, so length is not usually the deciding factor any more. The deciding factor is the quality of the text you get back.",
    },
    {
      question: "What does Rhino's AI cleanup actually do?",
      answer:
        "It runs your raw transcript through a language model on your Mac that removes filler words and false starts, applies punctuation and capitalisation, and structures what you said into the sentence you meant. It never leaves the machine, and it is skipped automatically when you are dictating into an AI assistant or a terminal.",
    },
    {
      question: "Can I use Rhino on an Intel Mac?",
      answer:
        "No. Rhino requires an Apple silicon Mac running macOS 14 or later. On an Intel Mac, Apple's built-in dictation is your best free option.",
    },
    {
      question: "Is Rhino worth $20 over a free feature?",
      answer:
        "Only if you dictate enough that editing literal transcripts costs you real time. If you dictate a few times a week, use Apple Dictation. If you dictate for an hour a day, the cleanup pass pays for the app in the first week.",
    },
  ],
};

export const metadata: Metadata = {
  title: "Rhino vs Apple Dictation (2026): Is Mac's Free Dictation Good Enough?",
  description:
    "macOS dictation is free and runs on-device — so when is it not enough? The honest gap is cleanup: Apple transcribes you literally, filler words and all. Compared by Rhino's founder.",
  alternates: { canonical: "https://rhinovoice.app/vs/apple-dictation" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/vs/apple-dictation",
    title: "Rhino vs Apple Dictation (2026): Is Mac's Free Dictation Good Enough?",
    description:
      "Start with the free one. Here is exactly where it stops being enough.",
  },
};

export default function Page() {
  return <ComparisonPage content={content} />;
}
