import { rhinoPrice } from "./site-chrome";

/**
 * One source of truth for every app the comparison pages rank. Prices and
 * claims were verified for the September 2026 comparison pages
 * (decisions.md 2026-09-17); update them here and every page follows.
 */
export const pricesChecked = "September 2026";

export type Cost =
  | { kind: "free" }
  | { kind: "once"; amount: number; currency?: "$" | "€"; approx?: boolean }
  | { kind: "monthly"; perMonth: number; billedAnnually: boolean; approx?: boolean };

export type Tool = {
  key: string;
  name: string;
  site?: string;
  /** Path of our head-to-head page, when one exists. */
  vs?: string;
  priceLine: string;
  /** What a year of the paid plan costs, for the cost table. */
  cost: Cost;
  where: string;
  good: string[];
  bad: string[];
};

export const tools: Record<string, Tool> = {
  rhino: {
    key: "rhino",
    name: "Rhino Voice",
    priceLine: `$${rhinoPrice} once, with a 30-day money-back guarantee. No free tier.`,
    cost: { kind: "once", amount: rhinoPrice },
    where: "On your Mac, always. There is no cloud option in the app.",
    good: [
      "Speech recognition and cleanup both run on your Mac, even with Wi-Fi off",
      "No account, no telemetry, no subscription",
      "A custom dictionary that fixes and boosts the names you say all day",
    ],
    bad: [
      "Apple silicon and macOS 14 or later only. No Windows, no iPhone, no Intel Mac",
      "The cleanup model is about a 1GB download",
      "Types only. It does not drive your Mac by voice",
    ],
  },
  wisprFlow: {
    key: "wisprFlow",
    name: "Wispr Flow",
    site: "https://wisprflow.ai/",
    vs: "/vs/wispr-flow",
    priceLine: "$15/month, or $12/month billed annually",
    cost: { kind: "monthly", perMonth: 12, billedAnnually: true },
    where: "On Wispr's servers",
    good: [
      "The most polished app in the category",
      "Runs on Mac, Windows and mobile",
      "SOC 2 Type II, ISO 27001 and a HIPAA-ready plan with a signed BAA",
    ],
    bad: ["Your dictation is processed in the cloud", "A subscription: $144 a year at the annual rate"],
  },
  superwhisper: {
    key: "superwhisper",
    name: "superwhisper",
    site: "https://superwhisper.com/",
    vs: "/vs/superwhisper",
    priceLine: "Free tier. Pro around $8.49/month, with a lifetime option",
    cost: { kind: "monthly", perMonth: 8.49, billedAnnually: false, approx: true },
    where: "On your Mac, with local models selected",
    good: [
      "A free tier that runs Whisper models locally and works offline",
      "Modes, custom prompts and per-app behavior",
    ],
    bad: [
      "Paid tier adds optional cloud models, so there is a cloud pathway",
      "More to configure than most people want",
    ],
  },
  voiceInk: {
    key: "voiceInk",
    name: "VoiceInk",
    site: "https://tryvoiceink.com/",
    priceLine: "Lifetime tiers from $29. Free if you build it yourself",
    cost: { kind: "once", amount: 29 },
    where: "On your Mac",
    good: [
      "Open source under GPLv3, built on whisper.cpp",
      "Power Mode: different dictation settings per app",
    ],
    bad: [
      "The free route means building from source in Xcode, with no auto-updates",
      "Cloud AI enhancement exists, though it is opt-in",
    ],
  },
  appleDictation: {
    key: "appleDictation",
    name: "Apple Dictation",
    vs: "/vs/apple-dictation",
    priceLine: "Free, built into macOS",
    cost: { kind: "free" },
    where: "On your Mac, on Apple silicon with on-device dictation enabled",
    good: ["Already installed and free", "Runs on-device, and runs on Intel Macs"],
    bad: ["Types you literally: ums, false starts and spoken punctuation included"],
  },
  voiceControl: {
    key: "voiceControl",
    name: "macOS Voice Control",
    site: "https://support.apple.com/guide/mac-help/use-voice-control-mchlp2839/mac",
    priceLine: "Free, built into macOS",
    cost: { kind: "free" },
    where: "On your Mac",
    good: [
      "Drives the whole Mac by voice: menus, clicking, correction phrases",
      "Free and already installed, under Accessibility in System Settings",
    ],
    bad: [
      "Less fluent than Dragon was at its best",
      "The command vocabulary takes about a week to feel natural",
    ],
  },
  aquaVoice: {
    key: "aquaVoice",
    name: "Aqua Voice",
    site: "https://aquavoice.com/",
    priceLine: "Free tier of 1,000 words. Pro $8/month billed annually",
    cost: { kind: "monthly", perMonth: 8, billedAnnually: true },
    where: "In their cloud",
    good: ["About half the price of Wispr Flow", "Runs on Windows and Intel Macs too"],
    bad: ["Still a cloud service: you save money, not privacy"],
  },
  typeless: {
    key: "typeless",
    name: "Typeless",
    site: "https://typeless.com/",
    priceLine: "Free tier of 8,000 words a week. Pro $12/month billed annually",
    cost: { kind: "monthly", perMonth: 12, billedAnnually: true },
    where: "In their cloud",
    good: [
      "8,000 free words a week is real daily use",
      "Mac, Windows, iPhone and Android",
    ],
    bad: ["Your audio is processed on their servers"],
  },
  macWhisper: {
    key: "macWhisper",
    name: "MacWhisper",
    site: "https://goodsnooze.gumroad.com/l/macwhisper",
    vs: "/vs/macwhisper",
    priceLine: "Free tier. Pro is a one-time license, around €59 on Gumroad",
    cost: { kind: "once", amount: 59, currency: "€", approx: true },
    where: "On your Mac",
    good: [
      "The specialist for files: recordings, meetings, video, YouTube URLs",
      "Speaker labels, subtitle export and batch jobs on Pro",
    ],
    bad: ["Dictation exists on the Gumroad version, but it is not what the app is built around"],
  },
  dragonWindows: {
    key: "dragonWindows",
    name: "Dragon Professional v16",
    priceLine: "Around $699 one-time, Windows only",
    cost: { kind: "once", amount: 699, approx: true },
    where: "On the Windows machine running it",
    good: ["Your trained vocabulary, macros and firm-wide workflows keep working"],
    bad: ["Windows only. On a Mac that means Parallels or a separate PC"],
  },
};

/** "$20", "about $306", "$0", for a cost over `years` years. */
export function costOver(cost: Cost, years: number): string {
  if (cost.kind === "free") return "$0";
  if (cost.kind === "once") {
    return `${cost.approx ? "about " : ""}${cost.currency ?? "$"}${cost.amount}`;
  }
  const total = Math.round(cost.perMonth * 12 * years);
  return `${cost.approx ? "about " : ""}$${total.toLocaleString("en-US")}`;
}

/** The short price for the ranked table. */
export function priceShort(cost: Cost): string {
  if (cost.kind === "free") return "Free";
  if (cost.kind === "once") {
    return `${cost.approx ? "~" : ""}${cost.currency ?? "$"}${cost.amount} once`;
  }
  return `${cost.approx ? "~" : ""}$${cost.perMonth}/mo${cost.billedAnnually ? " (yearly)" : ""}`;
}
