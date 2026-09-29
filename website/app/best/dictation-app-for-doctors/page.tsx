import type { Metadata } from "next";
import { BestForPage, type BestForContent } from "../../_components/best-for-page";

const content: BestForContent = {
  slug: "/best/dictation-app-for-doctors",
  label: "Best dictation app for doctors and clinicians",
  headline: "The best dictation app for doctors and clinicians on a Mac (2026)",
  dek: "Clinical documentation has split into two different products — ambient scribes that listen to the visit, and dictation that types what you say. I build one of the dictation apps, so read this with that in mind. The first thing to work out is which of the two you are shopping for.",
  shortAnswer:
    "If you want software to listen to the patient visit and draft the note for you, you want an ambient AI scribe, and those run in the cloud under a BAA — usually bought through your organisation. If you want to dictate your own notes, letters and messages faster than you can type them, an on-device Mac dictation app does that without any patient audio leaving the machine.",
  shortPicks: [
    { label: "Best for drafting the note from the visit", pick: "an ambient AI scribe your organisation has approved" },
    { label: "Best on-device dictation", pick: "Rhino Voice — nothing transmitted, $20 once (mine)" },
    { label: "Best free option", pick: "Apple Dictation, with on-device dictation enabled" },
    { label: "Best cloud dictation with a BAA", pick: "Wispr Flow's HIPAA-ready plan" },
  ],
  intro: [
    {
      heading: "Ambient scribe or dictation?",
      paragraphs: [
        "An ambient scribe records the conversation between you and the patient, sends it to a server, and returns a structured draft note. Freed, Abridge, Microsoft's Dragon Copilot and several others sell versions of this. They can save a lot of charting time, and they are necessarily cloud products that handle protected health information, so they come with a business associate agreement and, in most practices, a procurement process.",
        "Dictation is older and simpler: you talk, it types, and you decide what goes in the note. It is the right tool for referral letters, patient portal replies, the assessment and plan you would rather say than type, and everything outside the EHR. It does not need to hear the patient at all, which is why it can run entirely on your own computer.",
      ],
    },
    {
      heading: "What on-device means for HIPAA",
      paragraphs: [
        "A BAA exists to govern a vendor who creates, receives or stores PHI on your behalf. When transcription runs on your Mac and nothing is transmitted, the dictation vendor never receives anything, so there is no data flow for an agreement to cover. That makes on-device dictation much easier to justify — but your device still needs to be managed the way your organisation requires, and your compliance officer, not a software website, has the final say.",
      ],
    },
  ],
  picks: [
    {
      name: "An ambient AI scribe (Freed, Abridge, Dragon Copilot and others)",
      bestFor: "drafting the clinical note from the visit itself",
      price: "Subscription, per clinician; enterprise products are bought by the organisation",
      where: "In the vendor's cloud, under a BAA",
      body: [
        "If the job you want done is \"write my note from the encounter\", this is the category, and no dictation app on this page does it. The differences between products are in EHR integration, specialty templates and who is allowed to buy them — some sell to individual clinicians, some only to health systems.",
        "Ask your organisation first. Many already have one licensed, and an unapproved tool that records patient conversations is the kind of thing compliance teams notice.",
      ],
    },
    {
      name: "Rhino Voice",
      mine: true,
      bestFor: "dictating notes, letters and messages with nothing transmitted",
      price: "$20 once, with a 30-day money-back guarantee",
      where: "On your Mac, always — there is no cloud option in the app",
      body: [
        "Mine. Hold Fn, dictate, release, and cleaned-up text lands wherever the cursor is — an EHR text box in the browser, a letter in Word, a portal message. Speech recognition and the cleanup pass both run on your Mac, it works with Wi-Fi off, and there is no account.",
        "Clinical vocabulary is where general speech models slip, so the custom dictionary matters: add drug names, eponyms and the abbreviations you actually say, and Rhino corrects them and their near-miss hearings every time. History stays on the Mac, and you can switch it off so no transcript is kept.",
        "Honest limits: it is not an ambient scribe, it does not integrate with any EHR beyond typing into it, it has not been tuned on medical speech the way Dragon Medical was, and it needs an Apple silicon Mac on macOS 14 or later.",
      ],
      url: "/",
    },
    {
      name: "Apple Dictation",
      bestFor: "short notes at zero cost",
      price: "Free, built into macOS",
      where: "On your Mac, on Apple silicon with on-device dictation enabled",
      body: [
        "Free, already installed, and processed on-device on Apple silicon for supported languages. For a quick portal reply it is fine. It transcribes literally, so fillers and restarts land in the text, and it has no custom vocabulary to teach drug names to.",
      ],
    },
    {
      name: "Dragon Medical One",
      bestFor: "clinicians whose organisation already licenses it",
      price: "Subscription, usually bought by the organisation",
      where: "In Microsoft's cloud",
      body: [
        "The long-standing standard for medical dictation, with a vocabulary tuned for medicine and deep EHR integrations. It is now a cloud product from Microsoft and typically comes through your health system rather than being something you buy yourself. If you already have it, use it for charting.",
      ],
    },
    {
      name: "Wispr Flow",
      bestFor: "cloud dictation with a signed BAA",
      price: "$15/month, or $12/month billed annually; check which plan includes the BAA",
      where: "On Wispr's servers",
      body: [
        "A polished general dictation app that runs on Mac, Windows and mobile, and offers a HIPAA-ready plan with a signed BAA alongside SOC 2 Type II and ISO 27001. If you need dictation on several devices and are comfortable with a cloud vendor under contract, it is a sound choice. Make sure you are on the plan that includes the BAA before you dictate anything about a patient.",
      ],
      url: "https://wisprflow.ai/",
    },
  ],
  faq: [
    {
      question: "Is Rhino Voice HIPAA compliant?",
      answer:
        "HIPAA compliance is a property of how a practice handles PHI, not something an app can be certified for. What Rhino does is keep everything on your Mac: no audio or text is transmitted, so Rhino never receives PHI and there is no vendor data flow for a BAA to cover. Your device still has to meet your organisation's requirements — ask your compliance officer.",
    },
    {
      question: "What is the difference between an AI scribe and dictation?",
      answer:
        "An ambient AI scribe listens to the patient visit and drafts the clinical note for you, in the cloud. Dictation types exactly what you choose to say. Scribes save more charting time; dictation keeps you in control of the wording and can run fully on-device.",
    },
    {
      question: "Will a general dictation app get drug names right?",
      answer:
        "Common ones, usually. Less common drug names, eponyms and abbreviations are where general models slip. Add them to a custom dictionary once and they come back right. Dragon Medical still has the edge on specialised vocabulary out of the box.",
    },
    {
      question: "Does dictation work inside my EHR?",
      answer:
        "A system-wide dictation app types into any text field your Mac can focus, including EHRs that run in a browser. It does not integrate with EHR templates or structured fields the way Dragon Medical One or an ambient scribe can.",
    },
  ],
  ctaBody:
    "$20 once, no subscription, no account, and no patient words ever leave your Mac. If it does not earn its keep, email me inside 30 days and I will refund you.",
  checked: "September 2026",
};

export const metadata: Metadata = {
  title: "Best Dictation App for Doctors on Mac (2026): Scribes vs On-Device Dictation",
  description:
    "Ambient AI scribe or dictation? How clinicians should choose, what on-device means for HIPAA, and five options compared honestly by a competitor.",
  alternates: { canonical: "https://rhinovoice.app/best/dictation-app-for-doctors" },
  openGraph: {
    type: "article",
    url: "https://rhinovoice.app/best/dictation-app-for-doctors",
    title: "Best Dictation App for Doctors and Clinicians on Mac (2026)",
    description: "Ambient scribes and dictation are different products. Here is how to tell which you need.",
  },
};

export default function Page() {
  return <BestForPage content={content} />;
}
