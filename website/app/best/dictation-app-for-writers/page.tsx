import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-writers",
  label: "Best dictation app for writers",
  headline: "The best dictation app for writers on a Mac (2026)",
  dek: "Novelists, essayists, bloggers and anyone with a word count to hit. I make one of the apps below, so treat my enthusiasm for it with suspicion. The rest of the advice holds either way: dictation helps writers most in the first draft, and the right tool depends on whether you draft at a desk or on a walk.",
  shortAnswer:
    "Writers get the most from dictation on first drafts, where speed matters and polish comes later. If you draft at your desk, a hold-a-key dictation app with AI cleanup types straight into Scrivener, Word or Google Docs. If you draft on walks, record voice memos and transcribe them afterwards with a file transcription app.",
  shortPicks: [
    { label: "Best for drafting at the desk", pick: "Rhino Voice — cleans up as you go, $20 once (mine)" },
    { label: "Best for drafting on walks", pick: "MacWhisper, for transcribing voice memos" },
    { label: "Best free way to start", pick: "Apple Dictation" },
    { label: "Best for writers who switch between devices", pick: "Wispr Flow" },
  ],
  intro: [
    {
      heading: "Talk the draft, type the revision",
      paragraphs: [
        "Most people speak three to four times faster than they type, and a first draft rewards speed more than precision. The writers who stick with dictation tend to use it to get the shape of a chapter or an essay down, then edit at the keyboard — speaking is for generating, typing is for cutting.",
        "Which is why cleanup matters more to writers than raw accuracy. Spoken language is full of \"so, um, what I mean is\" and half-sentences you abandon. A tool that transcribes literally hands you a draft you have to scrub before you can even start revising. A tool that removes the filler and the false starts hands you something much closer to prose.",
      ],
    },
    {
      heading: "A note on privacy for unpublished work",
      paragraphs: [
        "An unpublished manuscript is the one thing a writer really does not want sitting on somebody else's server. Most cloud dictation companies have sensible policies, but if the idea of your novel passing through a third party bothers you, the on-device options on this list avoid it completely and cost less over a year than one month of most subscriptions.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "drafting at the desk with the filler already gone",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always",
      body: [
        "Mine. Hold Fn, talk the paragraph, release, and it lands at your cursor in Scrivener, Ulysses, Word, Google Docs or wherever you write — punctuated, capitalised, with the ums and restarts removed by a local AI pass. Double-press Fn to go hands-free and pace the room while you talk.",
        "Two features writers tend to love: spoken edits (switch them on in Settings), where you can say \"scratch that\" or \"actually, make that…\" mid-thought and only the corrected version is typed, and a custom dictionary for character names, invented places and the words your spellchecker refuses to learn. Longer runs of five minutes or more go to the clipboard rather than pasting a wall of text into the wrong window.",
        "Everything runs on your Mac, so the manuscript never leaves it. It needs Apple silicon and macOS 14 or later.",
      ],
      url: "/",
    },
    {
      name: "MacWhisper",
      bestFor: "writers who draft by talking into their phone on walks",
      price: "Free tier; Pro is a one-time licence, around €59 on Gumroad",
      where: "On your Mac",
      body: [
        "Plenty of writers do their best thinking away from the desk. Record the voice memo on the walk, drop it into MacWhisper when you get home, and get a full local transcript to edit. It handles long recordings and batch jobs well, and the Pro licence is a one-time purchase.",
        "It transcribes rather than rewrites, so a rambling memo comes back as a rambling transcript. That is often what you want at this stage.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
    {
      name: "Apple Dictation",
      bestFor: "trying dictation before you spend anything",
      price: "Free, built into macOS",
      where: "On your Mac, on Apple silicon with on-device dictation enabled",
      body: [
        "Free and already installed. Good enough to find out whether talking your drafts works for you at all. It transcribes literally, fillers included, and it has no custom vocabulary, so a fantasy novel's proper nouns will come back creatively spelled.",
      ],
    },
    {
      name: "superwhisper",
      bestFor: "writers who like to tinker with modes and prompts",
      price: "Free tier; Pro around $8.49/month, with a lifetime option",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      body: [
        "A free local tier plus a paid tier with custom modes, so you can build one mode that keeps your voice nearly verbatim and another that tidies a rough idea into bullet points. If you enjoy configuring your tools, this is the most flexible option here.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "Wispr Flow",
      bestFor: "writers who draft on a Mac, a PC and a phone",
      price: "$15/month, or $12/month billed annually",
      where: "On Wispr's servers",
      body: [
        "Polished, fast, and available on Mac, Windows and mobile, so the same dictation habit follows you everywhere. The trade is that your drafts are processed in the cloud and the subscription never ends.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  faq: [
    {
      question: "Is dictation actually faster than typing for writing?",
      answer:
        "For first drafts, usually yes — most people speak several times faster than they type. For revision, no; editing is still faster at the keyboard. Writers who stick with dictation use it to generate and the keyboard to cut.",
    },
    {
      question: "Does dictation work in Scrivener?",
      answer:
        "Yes. A system-wide dictation app like Rhino Voice types into whatever has focus on your Mac, including Scrivener, Ulysses, Word, Pages and Google Docs in a browser.",
    },
    {
      question: "Will AI cleanup change my voice?",
      answer:
        "Rhino's cleanup removes filler words, false starts and restarts and fixes punctuation; it is not asked to rewrite your style. If you want your words fully verbatim, cleanup can be switched off.",
    },
    {
      question: "How do I get character names spelled right?",
      answer:
        "Add them to a custom dictionary. Rhino also fixes near-miss hearings of a word you add, so one entry covers the ways the model tends to mishear it.",
    },
  ],
  ctaBody:
    "$20 once — less than one month of most subscriptions — and your manuscript never leaves your Mac. If it does not earn its keep, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Writers on Mac (2026): Draft by Voice",
  description:
    "How writers actually use dictation, why cleanup matters more than accuracy, and five Mac apps for drafting at the desk or on a walk — compared honestly by a competitor.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-writers" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-writers",
    title: "Best Dictation App for Writers on Mac (2026)",
    description: "Talk the draft, type the revision. Which tool fits how you write.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
