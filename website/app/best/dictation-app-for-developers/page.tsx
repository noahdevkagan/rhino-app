import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-developers",
  label: "Best dictation app for developers",
  headline: "The best dictation app for developers on Mac (2026)",
  dek: "Developers used to be the last people who needed dictation. Then half the job became writing prompts to Claude, Cursor and ChatGPT. I build Rhino with AI coding agents every day, so this is the page I care about most. I'm biased. Here's the real breakdown anyway.",
  shortAnswer:
    "For most developers, the win isn't dictating code. It's dictating the English around it: prompts to AI assistants, PR descriptions, commit messages, Slack and docs. Pick a dictation app that passes text through word-for-word to terminals and AI chat apps and cleans it up everywhere else. If you need to write and navigate code entirely by voice, use Talon.",
  shortPicks: [
    { label: "Best for prompting AI and writing around code", pick: "Rhino Voice. Word-for-word in terminals and AI apps, $20 once (mine)" },
    { label: "Best for coding fully by voice", pick: "Talon Voice, with Cursorless in VS Code" },
    { label: "Best open source", pick: "VoiceInk" },
    { label: "Best free option", pick: "superwhisper's free local tier" },
  ],
  intro: [
    {
      heading: "You're dictating prompts, not code",
      paragraphs: [
        "Nobody wants to say \"open paren, const, x, equals.\" What changed is that a good prompt to a coding agent is three paragraphs of context, constraints and what you actually want. That's exactly the kind of writing that's faster to say than type. Same for explaining a bug in Slack or writing up a PR.",
        "Here's the problem most dictation apps weren't built for. An AI cleanup pass that's great in an email can mangle an instruction meant for another AI. Or worse, try to answer it. A developer's dictation tool needs to know when to leave your words alone.",
      ],
    },
    {
      heading: "Your code probably shouldn't go to a third party",
      paragraphs: [
        "When you dictate about code, you're describing it: file names, internal service names, the bug in the auth path. A lot of companies have rules about which cloud tools that can go through. On-device dictation skips that whole conversation with your security team.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "prompting AI assistants and writing around code",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. Hold Fn, talk, let go, text lands at your cursor. In the Claude and ChatGPT desktop apps and in terminals (Terminal, iTerm2, Warp, WezTerm, kitty, Ghostty, Hyper), Rhino automatically skips cleanup so your instruction arrives exactly as you said it. In Slack, email and docs, it removes the ums and restarts.",
        "The custom dictionary handles the words speech models always butcher: repo names, internal services, library names, the teammate nobody spells right. Everything runs locally, so describing proprietary code doesn't send it anywhere. There's also a command line for transcribing files.",
        "What it doesn't do: voice commands, moving your cursor, navigating code. It types. Your hands drive. Apple silicon and macOS 14 or newer only.",
      ],
      url: "/",
    },
    {
      name: "Talon Voice",
      bestFor: "writing and navigating code entirely by voice",
      price: "Free; paid beta tier supports development",
      where: "On your computer",
      local: "Yes",
      body: [
        "If you need to code hands-free, because of RSI or just because, Talon is the real answer. It's a programmable voice-control system with community commands for editors, terminals and languages. Cursorless adds structural editing in VS Code by voice. Mac, Windows and Linux.",
        "It's a skill you learn over weeks, not an app you install and use today. For prose and prompts, most Talon people still pair it with a dictation app.",
      ],
      url: "https://talonvoice.com/",
    },
    {
      name: "VoiceInk",
      bestFor: "developers who want to read the source",
      price: "Lifetime from $29; free if you build it yourself",
      where: "On your Mac",
      local: "Yes",
      body: [
        "Open source (GPLv3), built on whisper.cpp. If you'd rather audit your dictation tool than trust it, this is the one. Power Mode lets you set different behavior per app, so your terminal and your email can be configured differently by hand.",
      ],
      url: "https://tryvoiceink.com/",
    },
    {
      name: "superwhisper",
      bestFor: "a free local tier with custom modes",
      price: "Free tier; Pro about $8.49/month, lifetime available",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      local: "Optional",
      body: [
        "The free tier runs locally and is a good way to find out if you'll actually dictate prompts. Pro adds custom modes, so you can build a \"prompt\" mode that leaves your words alone and a \"Slack\" mode that tidies them up.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "Wispr Flow",
      bestFor: "developers fine with a cloud tool on Mac and Windows",
      price: "$15/month, or $12/month billed yearly",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "Popular with developers, fast and polished, with Mac and Windows apps. It processes your speech in the cloud, so check your company's policy before you describe internal code into it.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  verdict: [
    "If you spend your day in Claude Code, Cursor or ChatGPT: you want dictation that doesn't mess with your prompts. That's why I built Rhino to go word-for-word in AI apps and terminals. Try it on your next ten prompts and watch how much more context you give the model when you don't have to type it.",
    "If your hands hurt and you need to actually write code by voice: Talon. Nothing else is close. Budget a few weeks to learn it.",
  ],
  today: [
    "Next time you write a prompt, say it out loud instead. Explain the bug like you would to a coworker. Notice how much more context you give.",
    "Make a list of your repo names, services and libraries. That's your custom dictionary.",
    "Check your company's policy on cloud AI tools. If it's strict, only look at the local options on this page.",
    "Try Rhino for a week in your terminal and AI apps. Refund if you go back to typing.",
  ],
  faq: [
    {
      question: "Can I write code by dictation?",
      answer:
        "Yes, but a regular dictation app is the wrong tool for it. Talon Voice, with Cursorless in VS Code, is built for writing and navigating code by voice. Dictation apps are best for the English around the code: prompts, comments, PR descriptions and chat.",
    },
    {
      question: "Why does AI cleanup matter when prompting an assistant?",
      answer:
        "A cleanup pass that rewrites your email can also rewrite, or try to act on, an instruction meant for another AI. Rhino Voice turns cleanup off automatically in the Claude and ChatGPT desktop apps and in common terminals, so prompts go through word-for-word.",
    },
    {
      question: "Does Rhino Voice work in Cursor or VS Code?",
      answer:
        "Yes. Rhino types into any text field on your Mac, including editor chat panels and built-in terminals. Editors keep cleanup on on purpose, because comments, docs and commit messages benefit from it. If you want a prompt in an editor's chat panel word-for-word, turn cleanup off in Settings.",
    },
    {
      question: "Is it safe to dictate about proprietary code?",
      answer:
        "With an on-device app like Rhino Voice, nothing you say is sent anywhere, so there's nothing to leak. With a cloud tool, your words go to the vendor's servers. Check your company's policy.",
    },
  ],
  ctaBody:
    "$20 once. Word-for-word where your prompts go, cleaned up everywhere else, and none of it leaves your Mac. Try it for 30 days. If you go back to typing, email me and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Developers on Mac (2026): Prompts, PRs and Code",
  description:
    "Developers now dictate prompts to AI assistants more than anything else. Five Mac options, including Talon for coding fully by voice, from someone who makes one of them.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-developers" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-developers",
    title: "Best Dictation App for Developers on Mac (2026)",
    description: "You're dictating prompts, not code. Pick a tool that knows when to leave your words alone.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
