import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-doctors",
  label: "Best dictation app for doctors and clinicians",
  headline: "The best dictation app for doctors and clinicians on Mac (2026)",
  dek: "I make a dictation app, so I'm biased. But I'm going to start by telling you that my app might be the wrong category for you. Clinical documentation split into two kinds of product, and most people shopping haven't figured out which one they need.",
  shortAnswer:
    "If you want software to listen to the patient visit and write the note for you, you want an ambient AI scribe. Those run in the cloud under a BAA and usually come through your organization. If you want to dictate your own notes, letters and messages faster than typing, an on-device Mac dictation app does it without any patient audio leaving your computer.",
  shortPicks: [
    { label: "Best for writing the note from the visit", pick: "An ambient AI scribe your organization approved" },
    { label: "Best on-device dictation", pick: "Rhino Voice. Nothing sent anywhere, $20 once (mine)" },
    { label: "Best free option", pick: "Apple Dictation" },
    { label: "Best cloud dictation with a BAA", pick: "Wispr Flow's HIPAA-ready plan" },
  ],
  intro: [
    {
      heading: "Scribe or dictation? Figure this out first",
      paragraphs: [
        "An ambient scribe records you and the patient talking, sends it to a server, and sends back a draft note. Freed, Abridge, Microsoft's Dragon Copilot and a bunch of others do this. They can save a ton of charting time. They're also cloud products handling protected health info, so they come with a BAA and usually a procurement process.",
        "Dictation is simpler. You talk, it types, you decide what goes in the note. It's great for referral letters, portal replies, the assessment and plan you'd rather say than type, and everything outside the EHR. It never needs to hear the patient, which is why it can run entirely on your own computer.",
      ],
    },
    {
      heading: "What \"on-device\" means for HIPAA",
      paragraphs: [
        "A BAA covers a vendor who creates, receives or stores PHI for you. If transcription runs on your Mac and nothing is sent anywhere, the dictation company never receives anything. There's no data flow for a BAA to cover.",
        "That makes on-device dictation way easier to justify. Your Mac still has to be managed the way your organization requires, and your compliance officer gets the final word, not a software website. Including mine.",
      ],
    },
  ],
  picks: [
    {
      name: "An ambient AI scribe (Freed, Abridge, Dragon Copilot and others)",
      bestFor: "writing the clinical note from the visit itself",
      price: "Subscription per clinician; enterprise versions bought by your organization",
      where: "In the vendor's cloud, under a BAA",
      local: "No",
      body: [
        "If what you want is \"write my note from the encounter,\" this is the category. Nothing else on this page does that. The differences between them are EHR integration, specialty templates, and who's allowed to buy. Some sell to individual clinicians, some only to health systems.",
        "Ask your organization first. A lot of them already have one licensed. And an unapproved tool that records patient conversations is exactly the thing compliance notices.",
      ],
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "dictating notes, letters and messages with nothing sent anywhere",
      price: "$20 once, 30-day money-back guarantee",
      where: "On your Mac. No cloud option in the app.",
      local: "Yes, always",
      body: [
        "Mine. Hold Fn, talk, let go, and clean text lands wherever your cursor is: an EHR text box in the browser, a letter in Word, a portal message. Speech recognition and cleanup both run on your Mac. Works with Wi-Fi off. No account.",
        "Medical vocabulary is where general speech models trip up, so the custom dictionary matters a lot here. Add drug names, eponyms and the abbreviations you actually say. Rhino fixes them and the ways it tends to mishear them. History stays on your Mac, and you can turn it off so no transcript is saved.",
        "What it's not: an ambient scribe. It doesn't plug into your EHR beyond typing into it. It hasn't been trained on medical speech the way Dragon Medical was. And it needs an Apple silicon Mac on macOS 14 or newer.",
      ],
      url: "/",
    },
    {
      name: "Apple Dictation",
      bestFor: "short notes for $0",
      price: "Free, built into macOS",
      where: "On your Mac (Apple silicon, on-device dictation on)",
      local: "Yes",
      body: [
        "Free, already installed, runs on-device on Apple silicon. For a quick portal reply, fine. It types exactly what you say, ums included, and there's no custom vocabulary to teach it drug names.",
      ],
    },
    {
      name: "Dragon Medical One",
      bestFor: "clinicians whose organization already pays for it",
      price: "Subscription, usually bought by your organization",
      where: "In Microsoft's cloud",
      local: "No",
      body: [
        "The long-time standard for medical dictation. Vocabulary tuned for medicine and deep EHR integration. It's a Microsoft cloud product now, and it usually comes through your health system, not your credit card. If you already have it, use it for charting.",
      ],
    },
    {
      name: "Wispr Flow",
      bestFor: "cloud dictation with a signed BAA",
      price: "$15/month or $12/month yearly; check which plan includes the BAA",
      where: "On Wispr's servers",
      local: "No",
      body: [
        "Polished dictation on Mac, Windows and phone, with a HIPAA-ready plan and signed BAA, plus SOC 2 Type II and ISO 27001. If you need dictation on multiple devices and you're fine with a cloud vendor under contract, it's a good pick. Just make sure you're on the plan with the BAA before you dictate anything about a patient.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  verdict: [
    "Most clinicians I'd point to two tools, not one. Use whatever ambient scribe your organization gives you for visit notes. Use on-device dictation for everything else: letters, portal messages, the emails that eat your evening.",
    "If your organization gives you nothing, start with Apple Dictation for free. If you're dictating a lot and the cleanup starts bugging you, that's when Rhino is worth $20.",
  ],
  today: [
    "Email your compliance or IT team: \"Do we have an approved ambient scribe or dictation tool?\" Don't buy anything until you hear back.",
    "Turn on Apple Dictation (System Settings → Keyboard → Dictation) and use it on your next five portal replies. Free.",
    "List the 25 drug names, eponyms and abbreviations you say every day. That's your custom dictionary in any app.",
    "If you want cleanup and nothing leaving your Mac, try Rhino for a week on non-chart work. Refund if it doesn't help.",
  ],
  faq: [
    {
      question: "Is Rhino Voice HIPAA compliant?",
      answer:
        "HIPAA compliance is about how a practice handles PHI. An app can't be certified for it. What Rhino does is keep everything on your Mac: no audio or text is sent anywhere, so Rhino never receives PHI and there's no vendor data flow for a BAA to cover. Your device still needs to meet your organization's requirements. Ask your compliance officer.",
    },
    {
      question: "What's the difference between an AI scribe and dictation?",
      answer:
        "An ambient AI scribe listens to the patient visit and writes the note for you, in the cloud. Dictation types exactly what you choose to say. Scribes save more charting time. Dictation keeps you in control of the words and can run fully on your computer.",
    },
    {
      question: "Will a general dictation app get drug names right?",
      answer:
        "Common ones, usually. Less common drug names, eponyms and abbreviations are where general models slip. Add them to a custom dictionary once and they come back right. Dragon Medical still wins on specialized vocabulary out of the box.",
    },
    {
      question: "Does dictation work inside my EHR?",
      answer:
        "A system-wide dictation app types into any text field on your Mac, including EHRs that run in a browser. It won't fill in EHR templates or structured fields the way Dragon Medical One or an ambient scribe can.",
    },
  ],
  ctaBody:
    "$20 once. No subscription, no account, and no patient info ever leaves your Mac. Try it for 30 days. If it doesn't save you time, email me and I'll refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Doctors on Mac (2026): AI Scribes vs Dictation",
  description:
    "Ambient AI scribe or dictation? How clinicians should choose, what on-device means for HIPAA, and five options compared by someone who makes one of them.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-doctors" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-doctors",
    title: "Best Dictation App for Doctors and Clinicians on Mac (2026)",
    description: "AI scribes and dictation are different products. Here's how to tell which one you need.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
