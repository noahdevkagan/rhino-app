import type { Metadata } from "next";
import { BEST_FOR_GUIDES } from "../_components/best-for-page";
import { BuyForm, SiteFooter, SiteHeader } from "../_components/site-chrome";

const jsonLd = [
  {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: [
      { "@type": "ListItem", position: 1, name: "Rhino", item: "https://rhinovoice.app/" },
      { "@type": "ListItem", position: 2, name: "Guides", item: "https://rhinovoice.app/best" },
    ],
  },
  {
    "@context": "https://schema.org",
    "@type": "ItemList",
    name: "Best dictation app guides",
    itemListElement: BEST_FOR_GUIDES.map((guide, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: guide.label,
      url: `https://rhinovoice.app${guide.href}`,
    })),
  },
];

export const metadata: Metadata = {
  title: "Best Dictation App for Mac, by Who You Are (2026 Guides)",
  description:
    "Ten guides to picking a Mac dictation app: for lawyers, doctors, writers, developers, ADHD, RSI, students, non-native speakers, journalists and offline use.",
  alternates: { canonical: "https://rhinovoice.app/best" },
  openGraph: {
    type: "website",
    url: "https://rhinovoice.app/best",
    title: "Best Dictation App for Mac, by Who You Are (2026 Guides)",
    description: "The right dictation app depends on the job. Ten guides from someone who makes one and says when it loses.",
  },
};

export default function Page() {
  return (
    <div className="doc-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }}
      />
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <SiteHeader />

      <main className="doc" id="main">
        <nav className="breadcrumb" aria-label="Breadcrumb">
          <a href="/">Rhino</a>
          <span aria-hidden="true">/</span>
          <span>Guides</span>
        </nav>

        <h1>The best dictation app for Mac depends on who you are</h1>
        <p className="dek">
          A lawyer protecting privilege, a developer prompting Claude and a student on
          a budget shouldn&apos;t buy the same thing. So I wrote a guide for each. Yes, I
          make Rhino Voice, and it shows up in all of them. It doesn&apos;t win all of
          them, and each page tells you when something else is better, including the
          free stuff.
        </p>

        <nav className="more-links" aria-label="Guides">
          <ul>
            {BEST_FOR_GUIDES.map((guide) => (
              <li key={guide.href}>
                <a href={guide.href}>{guide.label}</a>
              </li>
            ))}
          </ul>
        </nav>

        <p>
          Looking for a meeting tool instead? Same rules, same honesty:{" "}
          <a className="inline-link" href="https://meetmouse.com/best/">
            MeetMouse meeting tool guides
          </a>
          . MeetMouse is mine too.
        </p>

        <section className="doc-cta">
          <h2>Try Rhino Voice</h2>
          <p>
            $20 once. No subscription, no account, and nothing leaves your Mac. Try it
            for 30 days. If it&apos;s not worth it, email me and I&apos;ll refund you.
          </p>
          <BuyForm />
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
