import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-writers",
  label: "Best dictation app for writers",
  headline: "The best dictation app for writers on Mac (2026)",
  dek: "Novelists, bloggers, newsletter writers, anyone staring at a word count. I make one of these apps, so take my love for it with a grain of salt. Here's what actually matters: dictation is amazing for first drafts, and the right tool depends on whether you write at a desk or on a walk.",
  shortAnswer:
    "Writers get the most out of dictation on first drafts, where speed beats polish. If you draft at your desk, use a hold-a-key dictation app with AI cleanup that types straight into Scrivener, Word or Google Docs. If you draft on walks, record voice memos and transcribe them later with a file transcription app.",
  shortPicks: [
    { label: "Best for drafting at your desk", pick: "Rhino Voice. Cleans up as you go, $20 once (mine)" },
    { label: "Best for drafting on walks", pick: "MacWhisper, for your voice memos" },
    { label: "Best free way to start", pick: "Apple Dictation" },
    { label: "Best if you write on Mac, PC and phone", pick: "Wispr Flow" },
  ],
  intro: [
    {
      heading: "Talk the draft. Type the edit.",
      paragraphs: [
        "Most people talk three to four times faster than they type. A first draft rewards speed. That's the whole trick.",
        "The writers who stick with dictation use it to get the messy version out: the shape of the chapter, the argument of the post. Then they edit at the keyboard. Talking is for making stuff. Typing is for cutting it.",
        "That's why cleanup matters more to writers than raw accuracy. When we talk, we say \"so, um, what I mean is\" and abandon half our sentences. An app that types that literally gives you a mess to scrub before you can even start editing. An app that removes the filler gives you something close to prose.",
      ],
    },
    {
      heading: "Your unpublished book shouldn't live on someone's server",
      paragraphs: [
        "Most cloud dictation companies have fine policies. But if it bugs you that your novel is passing through a third party, the on-device options here avoid it completely. And they cost less for a year than one or two months of most subscriptions.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "drafting at your desk with the filler already gone",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. Hold Fn, talk the paragraph, let go, and it lands at your cursor in Scrivener, Ulysses, Word, Google Docs, wherever. Punctuated, capitalized, ums and restarts removed by an AI that runs on your Mac. Double-press Fn to go hands-free and pace around the room while you talk.",
        "Two things writers love. Spoken edits (turn them on in Settings): say \"scratch that\" or \"actually, make that...\" mid-thought and only the fixed version gets typed. And the custom dictionary, for character names, made-up places, and every word spellcheck refuses to learn.",
        "If you talk for five minutes or more, Rhino puts the text on your clipboard instead of dumping a wall of words into whatever window happened to be open. Your manuscript never leaves your Mac. Needs Apple silicon and macOS 14 or newer.",
      ],
      url: "/",
    },
    {
      name: "MacWhisper",
      bestFor: "writers who think best on walks",
      price: "Free tier; Pro is about €59 once on Gumroad",
      where: "On your Mac",
      local: "Yes",
      body: [
        "A lot of writers do their best thinking away from the desk. Record a voice memo on the walk, drop it into MacWhisper when you get home, get a full transcript to work from. Runs locally, handles long recordings, one-time price.",
        "It transcribes, it doesn't clean up. So a rambling memo comes back as a rambling transcript. At this stage that's usually what you want.",
      ],
      url: "https://goodsnooze.gumroad.com/l/macwhisper",
    },
    {
      name: "Apple Dictation",
      bestFor: "trying it before you spend a dollar",
      price: "Free, built into macOS",
      where: "On your Mac (Apple silicon, on-device dictation on)",
      local: "Yes",
      body: [
        "Free and already there. Good enough to find out if talking your drafts works for you. It types literally, filler and all, and has no custom vocabulary. Your fantasy novel's names will come back spelled creatively.",
      ],
    },
    {
      name: "superwhisper",
      bestFor: "writers who love tweaking their tools",
      price: "Free tier; Pro about $8.49/month, lifetime available",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      local: "Optional",
      body: [
        "Free local tier, plus a paid tier with custom modes. Build one mode that keeps your voice almost word-for-word and another that turns a rough idea into bullet points. If you love configuring things, this is the most flexible one here.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "Wispr Flow",
      bestFor: "writers who draft on a Mac, a PC and a phone",
      price: "$15/month, or $12/month billed yearly",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "Polished, fast, and on Mac, Windows and phone, so the habit follows you everywhere. The trade: your drafts go through the cloud, and the subscription never ends. $180 a year, every year.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  verdict: [
    "If you write at a desk: try Apple Dictation for a week. If you find yourself cleaning up ums and restarts more than you're writing, that's exactly the problem Rhino solves, and it's $20 once.",
    "If your ideas show up on walks: you don't need a dictation app, you need voice memos plus MacWhisper. Start with the free tier.",
    "Either way, don't expect dictation to edit for you. Talk the ugly draft fast, then fix it with your hands.",
  ],
  today: [
    "Set a timer for 10 minutes and talk your next section out loud with Apple Dictation (System Settings → Keyboard → Dictation). Don't stop to fix anything.",
    "Count the words. Compare that to your normal 10 minutes of typing.",
    "Add your character names and weird words to a custom dictionary list now. You'll need it in any app.",
    "If the speed is real but the cleanup is killing you, try Rhino for a week. Refund if it doesn't stick.",
  ],
  faq: [
    {
      question: "Is dictation actually faster than typing for writing?",
      answer:
        "For first drafts, usually yes. Most people talk several times faster than they type. For editing, no. Editing is still faster at the keyboard. Writers who stick with dictation talk to create and type to cut.",
    },
    {
      question: "Does dictation work in Scrivener?",
      answer:
        "Yes. A system-wide dictation app like Rhino Voice types into whatever app has focus on your Mac, including Scrivener, Ulysses, Word, Pages and Google Docs in a browser.",
    },
    {
      question: "Will AI cleanup change my voice?",
      answer:
        "Rhino's cleanup removes filler words, false starts and restarts and fixes punctuation. It's not rewriting your style. If you want your words exactly as spoken, you can turn cleanup off.",
    },
    {
      question: "How do I get character names spelled right?",
      answer:
        "Add them to a custom dictionary. Rhino also catches near-miss versions of a word you add, so one entry covers the ways it tends to mishear it.",
    },
  ],
  ctaBody:
    "$20 once, which is less than two months of most subscriptions. Your manuscript never leaves your Mac. Try it for 30 days. If it doesn't help you write more, email me and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Writers on Mac (2026): Draft by Voice",
  description:
    "How writers actually use dictation, why cleanup matters more than accuracy, and five Mac apps for drafting at your desk or on a walk. From someone who makes one of them.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-writers" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-writers",
    title: "Best Dictation App for Writers on Mac (2026)",
    description: "Talk the draft, type the edit. Which tool fits how you write.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
