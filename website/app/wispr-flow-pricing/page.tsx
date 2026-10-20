import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../_components/best-for-page";

const content: BestForContent = {
  slug: "/wispr-flow-pricing",
  label: "Wispr Flow pricing and discount codes",
  crumbParent: null,
  headline: "Wispr Flow pricing, free plan and discount codes (2026)",
  dek: "Full disclosure: I make Rhino Voice, which competes with Wispr Flow. I don't have a Wispr Flow coupon and I'm not affiliated with them. People keep asking what Flow really costs and whether the discount codes are real, so here's the straight answer from their own pricing page.",
  shortAnswer:
    "Wispr Flow's free plan gives you 2,000 words a week on desktop and a smaller weekly allowance on mobile. Pro is $15 a month, or $12 a month billed yearly ($144 a year), with unlimited dictation. There's no public discount code. The real discounts are 50% off Pro for students and educators with an education email, a discounted rate for nonprofits, and the 20% you save by paying yearly.",
  shortPicks: [
    { label: "Is it free?", pick: "Yes, 2,000 words a week on desktop" },
    { label: "Pro price", pick: "$15/month, or $12/month billed yearly ($144/year)" },
    { label: "Discount code", pick: "No public code; 50% off for students and educators" },
    { label: "Cheapest way to unlimited", pick: "Pay yearly, or get the education discount" },
  ],
  topCta:
    "Want unlimited dictation without the monthly bill? Rhino is free to start and $20 once for unlimited, and it runs on your Mac.",
  intro: [
    {
      heading: "What the free plan gets you",
      paragraphs: [
        "Flow's free plan is the full app with a word cap: 2,000 words a week on Mac and Windows, and limited weekly use on iPhone and Android. 2,000 words is roughly 15 minutes of talking. That's enough to find out whether hold-to-talk dictation works for you, which is the real question.",
        "If you dictate every day you'll hit the cap by midweek. That's the point where people start searching for discount codes.",
      ],
    },
    {
      heading: "What Pro costs over time",
      paragraphs: [
        "Pro removes the word cap and gives the meeting Notetaker longer limits. It's $15 a month, or $12 a month if you pay for the year up front.",
        "Over one year that's $180 monthly or $144 yearly. Over three years it's $540 or $432. That's the honest cost of a cloud dictation subscription: you pay for as long as you talk.",
        "Teams have Growth and Enterprise plans with admin controls, SSO and compliance features at higher prices.",
      ],
    },
    {
      heading: "About Wispr Flow discount codes",
      paragraphs: [
        "I couldn't find a working public coupon, and Wispr Flow doesn't advertise one. Coupon sites mostly recycle expired codes.",
        "What's real, from Wispr Flow's own pricing FAQ: students and educators with an education email get 50% off Pro, and nonprofits get a discounted rate. Paying yearly is a built-in 20% discount.",
        "If you're a student, that puts unlimited Flow at about half price. It's still a subscription.",
      ],
    },
  ],
  picks: [
    {
      name: "Wispr Flow Free",
      bestFor: "trying dictation across Mac, Windows and your phone",
      price: "Free, 2,000 words a week on desktop",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "Start here, especially if you also dictate on Windows or a phone. Rhino can't help you there. Use it for a week and see whether you hit the cap.",
      ],
      url: "https://wisprflow.ai/",
      linkText: "Visit Wispr Flow",
    },
    {
      name: "Wispr Flow Pro",
      bestFor: "heavy dictators on several devices who are fine with the cloud",
      price: "$15/month or $12/month billed yearly; 50% off for students and educators",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "It's the most polished app in the category, and it runs everywhere. If you need it on Windows and your phone too, it's worth paying for. Pay yearly, and take the education discount if you qualify.",
      ],
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "Mac-only dictation where your words never leave the computer",
      price: "Free for 2,000 words a week (unlimited your first week); $20 once for unlimited",
      where: "On your Mac, always",
      local: "Yes, always",
      body: [
        "Mine. Same hold-a-key, talk, release flow as Flow, and the same 2,000 free words a week. The difference is what happens when you outgrow it: unlimited is $20 once instead of $144 a year, and nothing you say is sent anywhere. It works with Wi-Fi off.",
        "It's Mac only, Apple silicon, macOS 14 or newer. No Windows, no phone app. If you dictate on your phone a lot, Flow is the better fit. More detail in my full comparison: Rhino Voice vs Wispr Flow.",
      ],
      url: "/vs/wispr-flow",
      linkText: "Rhino Voice vs Wispr Flow",
    },
    {
      name: "superwhisper",
      bestFor: "a free tier with local models and lots of settings",
      price: "Free tier; Pro $8.49/month, $84.99/year or $249.99 lifetime",
      where: "On your Mac with local models, or in the cloud on Pro",
      local: "Optional",
      body: [
        "Cheaper than Flow, and its free tier runs Whisper models on your Mac. Expect more settings to learn. Full breakdown: superwhisper pricing.",
      ],
      url: "/superwhisper-pricing",
      linkText: "superwhisper pricing and discount codes",
    },
    {
      name: "VoiceInk",
      bestFor: "a one-time price and open source code",
      price: "From $25 once (one Mac); free if you build it yourself",
      where: "On your Mac",
      local: "Yes",
      body: [
        "Open source, local, and paid once: $25 for one Mac, $39 for two, $49 for three, with a 14-day refund. It's the closest thing to Flow on the Mac without a subscription, other than Rhino.",
      ],
      url: "https://tryvoiceink.com/",
    },
  ],
  verdict: [
    "Use Flow's free plan for a week. If you never hit 2,000 words, you don't need to pay anyone.",
    "If you need dictation on Windows or your phone, buy Flow Pro yearly, with the education discount if you can get it.",
    "If you only dictate on a Mac, I'd try Rhino before subscribing. Unlimited costs less than two months of Flow, once.",
  ],
  today: [
    "Install Flow's free plan and dictate your email and Slack for a week.",
    "Check your word count on Friday. Under 2,000? Stay free.",
    "Over it and you're a student or teacher? Sign up with your education email for 50% off Pro.",
    "Mac only? Download Rhino free and run it side by side for a few days before you pay for either.",
  ],
  faq: [
    {
      question: "Is Wispr Flow free?",
      answer:
        "Yes. Wispr Flow's free plan includes 2,000 words a week on Mac and Windows and limited weekly use on mobile. Pro removes the cap.",
    },
    {
      question: "How much is Wispr Flow Pro?",
      answer:
        "$15 per month billed monthly, or $12 per month billed yearly ($144 a year), as listed on Wispr Flow's pricing page in October 2026.",
    },
    {
      question: "Is there a Wispr Flow discount code?",
      answer:
        "There's no public discount code. Wispr Flow gives students and educators with an education email 50% off Pro, offers nonprofits a discounted rate, and the yearly plan saves 20% over monthly.",
    },
    {
      question: "Is Wispr Flow free for students?",
      answer:
        "The free plan is free for everyone, students included. Students and educators get 50% off Pro with an education email.",
    },
    {
      question: "Is there a cheaper alternative to Wispr Flow on Mac?",
      answer:
        "Yes. Rhino Voice is free for 2,000 words a week and $20 once for unlimited, and runs entirely on your Mac. VoiceInk is from $25 once. superwhisper has a free tier and cheaper Pro plans. None of them match Flow on Windows and phones the way Flow does.",
    },
    {
      question: "Is this Wispr Flow's official site?",
      answer:
        "No. This page is by the maker of Rhino Voice, a competing Mac dictation app. For official pricing and support, go to wisprflow.ai.",
    },
  ],
  ctaBody:
    "Free to start, then $20 once for unlimited. No subscription, no account, and nothing leaves your Mac. If it doesn't save you time, email me within 30 days and I'll refund you.",
  checked: "October 2026",
};

export const metadata: Metadata = {
  title: "Wispr Flow Pricing (2026): Free Plan, Pro Cost, Discount Codes",
  description:
    "What Wispr Flow costs in 2026: the 2,000-word free plan, Pro at $15/mo or $144/yr, and which discounts are real (50% off for students). Not affiliated.",
  alternates: { canonical: "https://rhinovoice.app/wispr-flow-pricing" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/wispr-flow-pricing",
    title: "Wispr Flow Pricing, Free Plan and Discount Codes (2026)",
    description: "The straight answer on what Wispr Flow costs and which discounts are real.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
