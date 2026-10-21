import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../_components/best-for-page";

const content: BestForContent = {
  slug: "/superwhisper-pricing",
  label: "superwhisper pricing and discount codes",
  crumbParent: null,
  headline: "superwhisper pricing, free tier and discount codes (2026)",
  dek: "Full disclosure: I make Rhino Voice, a different Mac dictation app. I don't make superwhisper and I don't have a coupon for it. But \"superwhisper discount code\" is one of the things people search before buying, so here's what it actually costs and which discounts are real.",
  shortAnswer:
    "superwhisper has a free tier that keeps working forever, plus a 3,000-word trial of the Pro features. Pro is $8.49 a month, $84.99 a year, or $249.99 once for a lifetime license. There's no public discount code. The real discounts are 40% off for students, and the yearly plan, which costs about two months less than paying monthly. Every paid plan has a 30-day refund.",
  shortPicks: [
    { label: "Is it free?", pick: "Yes, a free tier with no time limit, plus 3,000 words of Pro to try" },
    { label: "Pro price", pick: "$8.49/month, $84.99/year or $249.99 lifetime" },
    { label: "Discount code", pick: "No public code; 40% off for students" },
    { label: "Refund", pick: "30 days on every paid plan" },
  ],
  topCta:
    "Want unlimited on-device dictation without a subscription? Rhino is free to start and $20 once for unlimited.",
  intro: [
    {
      heading: "What the free tier gets you",
      paragraphs: [
        "More than most free tiers. superwhisper's free plan types your voice into any app, records meetings on the Mac, handles 100+ languages and lets you use the local Whisper models as much as you want. You also get custom prompts, which is unusual for free.",
        "New accounts get the Pro features for their first 3,000 words. After that you drop to the free tier, and superwhisper says the free features are yours forever. 3,000 words is about 20 minutes of talking, so you'll know within a day or two whether you miss Pro.",
      ],
    },
    {
      heading: "What Pro adds",
      paragraphs: [
        "Pro is about models and files. You get unlimited use of superwhisper's cloud and local AI models, you can plug in your own AI API keys, translate any language into English, and transcribe audio and video files. Priority support comes with it.",
        "The price is the same Pro plan paid three ways: $8.49 a month, $84.99 a year, or $249.99 once. Monthly works out to $101.88 a year, so yearly saves you about $17. Lifetime pays for itself against yearly in a little under three years. If you're sure you'll still be dictating in 2029, lifetime is the better deal.",
        "One thing to know before you upgrade: Pro's extra power is mostly cloud models. If you picked superwhisper because it can run locally, the free tier's Whisper models already do that.",
      ],
    },
    {
      heading: "About superwhisper discount codes",
      paragraphs: [
        "I couldn't find a working public coupon, and superwhisper's own site doesn't advertise one. The codes on coupon sites are mostly old promos or bait to get you to click.",
        "What's real: students get 40% off Pro, which superwhisper shows right on its pricing section. The yearly plan is the other built-in discount (they call it two months free). And there's a 30-day refund, so trying Pro costs nothing if you cancel in time.",
        "Teams can ask about Enterprise, which adds SOC 2 Type II, centralized billing and volume discounts at a custom price.",
      ],
    },
  ],
  picks: [
    {
      name: "superwhisper Free",
      bestFor: "trying local dictation without paying anything",
      price: "Free, plus 3,000 words of Pro to start",
      where: "On your Mac with the local Whisper models",
      local: "Yes",
      body: [
        "Start here. Use it for a week of real work: email, Slack, notes. If the free tier covers it, you're done and it cost nothing.",
      ],
      url: "https://superwhisper.com/",
      linkText: "Visit superwhisper",
    },
    {
      name: "superwhisper Pro",
      bestFor: "power users who want cloud models, file transcription and translation",
      price: "$8.49/month, $84.99/year or $249.99 once; 40% off for students",
      where: "Your choice of local or cloud models",
      local: "Optional",
      body: [
        "If you want to switch between models, bring your own API keys or transcribe files, Pro is fair value, and the lifetime license is the one I'd buy. Students should use the 40% discount instead of hunting for codes.",
      ],
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "simple hold-to-talk dictation that never leaves your Mac",
      price: "Free for 2,000 words a week (unlimited your first week); $20 once for unlimited",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. A lot of people look at superwhisper, open the settings, and realize they just wanted to hold a key, talk, and have clean text show up. That's all Rhino does. There's no cloud model to pick, so there's no way to send audio off your Mac by accident.",
        "Unlimited is $20 once, about a twelfth of superwhisper's lifetime price. It's Mac only, Apple silicon, macOS 14 or newer, and it doesn't transcribe or translate files the way superwhisper Pro does.",
      ],
      url: "/",
    },
    {
      name: "VoiceInk",
      bestFor: "a one-time price and open source code",
      price: "From $25 once (one Mac); free if you build it yourself",
      where: "On your Mac",
      local: "Yes",
      body: [
        "Open source and sold as a lifetime license: $25 for one Mac, $39 for two, $49 for three, with a 14-day refund. If you're comfortable in Xcode you can build it from source for free, without auto-updates.",
      ],
      url: "https://tryvoiceink.com/",
    },
  ],
  verdict: [
    "Use superwhisper's free tier first. It's genuinely good, and the 3,000-word Pro trial tells you whether Pro is worth it.",
    "If you want Pro and you'll use it for years, the $249.99 lifetime license beats paying yearly after about three years. Students: take the 40% off.",
    "If what you want is simple, private dictation with nothing to configure, try Rhino before you pay for anything.",
  ],
  today: [
    "Download superwhisper from its official site and dictate your next ten emails with it.",
    "Watch your first 3,000 words. Did you use a Pro feature (cloud models, files, translation)? If not, stay on free.",
    "Students: verify your status at checkout for 40% off. Everyone else: skip the coupon sites.",
    "Want something simpler? Download Rhino free and compare them on the same emails.",
  ],
  faq: [
    {
      question: "Is superwhisper free?",
      answer:
        "Yes. superwhisper has a free tier with dictation in any app, meeting recording on Mac, 100+ languages and unlimited local Whisper models. New accounts also get Pro features for their first 3,000 words.",
    },
    {
      question: "How much is superwhisper Pro?",
      answer:
        "$8.49 a month, $84.99 a year, or $249.99 once for a lifetime license, as listed on superwhisper's site in October 2026. All paid plans come with a 30-day refund.",
    },
    {
      question: "Is there a superwhisper discount code?",
      answer:
        "There's no public discount code. superwhisper offers 40% off for students, and the yearly plan costs about two months less than paying monthly.",
    },
    {
      question: "Is superwhisper's lifetime license worth it?",
      answer:
        "If you'll use Pro for about three years or more, yes. $249.99 once versus $84.99 a year breaks even a little before the three-year mark.",
    },
    {
      question: "Is this superwhisper's official site?",
      answer:
        "No. This page is by the maker of Rhino Voice, a different Mac dictation app. For official pricing and support, go to superwhisper.com.",
    },
  ],
  ctaBody:
    "If you want unlimited private dictation without a subscription: free to start, then $20 once. If it doesn't save you time, email me within 30 days and I'll refund you.",
  checked: "October 2026",
};

export const metadata: Metadata = {
  title: "superwhisper Pricing (2026): Free Tier, Pro, Lifetime, Discounts",
  description:
    "What superwhisper costs in 2026: the free tier, Pro at $8.49/mo or $249.99 lifetime, and which discount codes are real (students get 40% off). Not affiliated.",
  alternates: { canonical: "https://rhinovoice.app/superwhisper-pricing" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/superwhisper-pricing",
    title: "superwhisper Pricing, Free Tier and Discount Codes (2026)",
    description: "The straight answer on what superwhisper costs and which discounts are real.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
