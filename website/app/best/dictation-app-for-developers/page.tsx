import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-developers",
  label: "Best dictation app for developers",
  headline: "The best dictation app for developers on a Mac (2026)",
  dek: "Developers used to be the last people who needed dictation. Then half the job became writing prompts to Claude, Cursor and ChatGPT, plus the Slack threads, PR descriptions and design docs around them. I build one of these apps; here is how I would choose if I did not.",
  shortAnswer:
    "For most developers the win is not dictating code, it is dictating the English around it: prompts to AI assistants, PR descriptions, commit messages, Slack and docs. Pick a dictation app that passes text through verbatim to terminals and AI chat boxes and cleans it up everywhere else. If you need to write and navigate code entirely by voice, use Talon.",
  shortPicks: [
    { label: "Best for prompting AI and writing around code", pick: "Rhino Voice — verbatim in terminals and AI apps, $20 once (mine)" },
    { label: "Best for coding entirely by voice", pick: "Talon Voice, with Cursorless in VS Code" },
    { label: "Best open-source option", pick: "VoiceInk" },
    { label: "Best free option", pick: "superwhisper's free local tier" },
  ],
  intro: [
    {
      heading: "You are dictating prompts, not code",
      paragraphs: [
        "Nobody wants to say \"open paren, const, x, equals\". What changed is that a good prompt to a coding agent is three paragraphs of context, constraints and intent, and that is exactly the kind of writing that is faster to say than to type. The same goes for explaining a bug in Slack or writing up a PR.",
        "That creates a problem most dictation apps were not designed for: an AI cleanup pass that is helpful in an email can mangle an instruction meant for another AI — or worse, try to answer it. A developer's dictation tool needs to know when to leave your words alone.",
      ],
    },
    {
      heading: "And your code probably should not go to a third party",
      paragraphs: [
        "When you dictate about proprietary code you are describing it: file names, internal service names, the bug in the auth path. Many companies have rules about which cloud tools that may pass through. On-device dictation sidesteps that conversation with your security team.",
      ],
    },
  ],
  picks: [
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "prompting AI assistants and writing around code",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always",
      body: [
        "Mine, and built by someone who dictates prompts all day. Hold Fn, talk, release, and the text lands at your cursor. In the Claude and ChatGPT desktop apps and in terminals — Terminal, iTerm2, Warp, WezTerm, kitty, Ghostty and Hyper — Rhino skips its cleanup pass automatically so the instruction arrives exactly as you said it. In Slack, email and docs it removes the ums and false starts.",
        "The custom dictionary handles the words speech models always get wrong: your repo names, internal services, library names, the teammate whose name nobody spells right. Everything runs locally, so describing proprietary code does not send it anywhere. There is also a command-line interface for transcribing files.",
        "What it does not do: voice commands, cursor movement or code navigation. It types; your hands drive. Apple silicon and macOS 14 or later only.",
      ],
      url: "/",
    },
    {
      name: "Talon Voice",
      bestFor: "writing and navigating code entirely by voice",
      price: "Free; a paid beta tier supports development",
      where: "On your computer",
      body: [
        "If you need to code hands-free — because of RSI, or because you want to — Talon is the serious answer. It is a programmable voice-control system with a community command set for editors, terminals and languages, and Cursorless adds structural editing in VS Code by voice. It runs on Mac, Windows and Linux.",
        "It is a skill you learn over weeks, not an app you install and use. For prose and prompts, most Talon users still pair it with a dictation mode or a separate dictation app.",
      ],
      url: "https://talonvoice.com/",
    },
    {
      name: "VoiceInk",
      bestFor: "developers who want to read the source",
      price: "Lifetime tiers from $29; free if you build it yourself",
      where: "On your Mac",
      body: [
        "Open source under GPLv3, built on whisper.cpp. If you would rather audit your dictation tool than trust it, this is the one. Power Mode lets you set different behaviour per app, so your terminal and your email client can be configured differently by hand.",
      ],
      url: "https://tryvoiceink.com/",
    },
    {
      name: "superwhisper",
      bestFor: "a free local tier with custom modes",
      price: "Free tier; Pro around $8.49/month, with a lifetime option",
      where: "On your Mac with local models; in the cloud if you pick a cloud model",
      body: [
        "The free tier runs local models and is a good way to find out whether you will actually dictate prompts. Pro adds custom modes, so you can build a \"prompt\" mode that leaves your words alone and a \"Slack\" mode that tidies them.",
      ],
      url: "https://superwhisper.com/",
    },
    {
      name: "Wispr Flow",
      bestFor: "developers happy with a cloud tool across Mac and Windows",
      price: "$15/month, or $12/month billed annually",
      where: "On Wispr's servers",
      body: [
        "Popular with developers, fast, and polished, with Mac and Windows apps. It processes your speech in the cloud, so check it against your company's policy before you describe internal code into it.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  faq: [
    {
      question: "Can I write code by dictation?",
      answer:
        "Yes, but a general dictation app is the wrong tool for it. Talon Voice, with Cursorless in VS Code, is built for writing and navigating code by voice. Dictation apps are best for the English around the code — prompts, comments, PR descriptions and chat.",
    },
    {
      question: "Why does AI cleanup matter when prompting an assistant?",
      answer:
        "A cleanup pass that rewrites your email can also rewrite, or try to act on, an instruction meant for another AI. Rhino Voice turns cleanup off automatically in the Claude and ChatGPT desktop apps and in common terminals, so prompts pass through verbatim.",
    },
    {
      question: "Does Rhino Voice work in Cursor or VS Code?",
      answer:
        "Yes. Rhino types into any focused text field on your Mac, including editor chat panels and integrated terminals. Editors deliberately keep cleanup on, because comments, docs and commit messages benefit from it; if you want a prompt in an editor's chat panel verbatim, switch cleanup off in Settings.",
    },
    {
      question: "Is it safe to dictate about proprietary code?",
      answer:
        "With an on-device app like Rhino Voice, nothing you say is transmitted, so there is nothing to leak. With a cloud tool, your words are processed on the vendor's servers — check your company's policy.",
    },
  ],
  ctaBody:
    "$20 once, verbatim where your prompts go, cleaned up everywhere else, and none of it leaves your Mac. If it does not earn its keep, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Developers on Mac (2026): Prompts, PRs and Code",
  description:
    "Developers now dictate prompts to AI assistants more than anything else. Five Mac options compared by a competitor, including Talon for coding fully by voice.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-developers" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-developers",
    title: "Best Dictation App for Developers on Mac (2026)",
    description: "You are dictating prompts, not code. Pick a tool that knows when to leave your words alone.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
