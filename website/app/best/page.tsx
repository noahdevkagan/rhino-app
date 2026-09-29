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
    "Ten honest guides to choosing a Mac dictation app — for lawyers, doctors, writers, developers, ADHD, RSI, students, non-native speakers, journalists and offline use.",
  alternates: { canonical: "https://rhinovoice.app/best" },
  openGraph: {
    type: "website",
    url: "https://rhinovoice.app/best",
    title: "Best Dictation App for Mac, by Who You Are (2026 Guides)",
    description: "The right dictation app depends on the job. Ten guides, written by a competitor who says so.",
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
          a budget should not buy the same thing. These guides pick the right tool for
          each job. I make Rhino Voice, which appears in all of them and wins some of
          them — each page says where it does not.
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

        <section className="doc-cta">
          <h2>Try Rhino Voice</h2>
          <p>
            $20 once, no subscription and no account, and nothing leaves your Mac. If it
            does not earn its keep, email me inside 30 days and I will refund you.
          </p>
          <BuyForm />
        </section>
      </main>

      <SiteFooter />
    </div>
  );
}
