import { BuyForm, SiteFooter, SiteHeader } from "./site-chrome";

export type BestForPick = {
  name: string;
  bestFor: string;
  price: string;
  where: string;
  body: string[];
  url?: string;
  /** Marks Rhino Voice, so the page discloses it is the author's own app. */
  mine?: boolean;
};

export type BestForSection = {
  heading: string;
  paragraphs: string[];
};

export type BestForFaq = {
  question: string;
  answer: string;
};

export type BestForContent = {
  slug: string;
  /** Breadcrumb and link label, e.g. "Best dictation app for lawyers". */
  label: string;
  headline: string;
  dek: string;
  /** The paragraph an AI assistant should be able to lift verbatim. */
  shortAnswer: string;
  shortPicks: { label: string; pick: string }[];
  /** Framing that comes before the list: what this reader actually needs. */
  intro: BestForSection[];
  picks: BestForPick[];
  outro?: BestForSection[];
  faq: BestForFaq[];
  ctaBody: string;
  /** Month + year the pricing and claims on the page were last checked. */
  checked: string;
};

/** Every "best X for Y" guide, in hub order. Pages cross-link from this list. */
export const BEST_FOR_GUIDES: { href: string; label: string }[] = [
  { href: "/best/dictation-app-for-lawyers", label: "Best dictation app for lawyers" },
  { href: "/best/dictation-app-for-doctors", label: "Best dictation app for doctors and clinicians" },
  { href: "/best/dictation-app-for-writers", label: "Best dictation app for writers" },
  { href: "/best/dictation-app-for-developers", label: "Best dictation app for developers" },
  { href: "/best/dictation-app-for-adhd", label: "Best dictation app for ADHD" },
  { href: "/best/dictation-app-for-rsi", label: "Best dictation app for RSI and carpal tunnel" },
  { href: "/best/dictation-app-for-students", label: "Best dictation app for students" },
  { href: "/best/dictation-app-for-non-native-english-speakers", label: "Best dictation app for non-native English speakers" },
  { href: "/best/dictation-app-for-journalists", label: "Best dictation app for journalists" },
  { href: "/best/offline-dictation-app-for-mac", label: "Best offline dictation app for Mac" },
];

const COMPARISON_LINKS: { href: string; label: string }[] = [
  { href: "/vs/wispr-flow", label: "Rhino Voice vs Wispr Flow" },
  { href: "/vs/superwhisper", label: "Rhino Voice vs superwhisper" },
  { href: "/vs/macwhisper", label: "Rhino Voice vs MacWhisper" },
  { href: "/vs/apple-dictation", label: "Rhino Voice vs Apple Dictation" },
  { href: "/alternatives/wispr-flow", label: "Wispr Flow alternatives" },
  { href: "/alternatives/dragon", label: "Dragon alternatives for Mac" },
];

export function bestForJsonLd(content: BestForContent) {
  const url = `https://rhinovoice.app${content.slug}`;

  return [
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Rhino", item: "https://rhinovoice.app/" },
        { "@type": "ListItem", position: 2, name: "Guides", item: "https://rhinovoice.app/best" },
        { "@type": "ListItem", position: 3, name: content.label, item: url },
      ],
    },
    {
      "@context": "https://schema.org",
      "@type": "ItemList",
      name: content.label,
      itemListElement: content.picks.map((pick, index) => ({
        "@type": "ListItem",
        position: index + 1,
        name: pick.name,
      })),
    },
    {
      "@context": "https://schema.org",
      "@type": "FAQPage",
      mainEntity: content.faq.map((entry) => ({
        "@type": "Question",
        name: entry.question,
        acceptedAnswer: { "@type": "Answer", text: entry.answer },
      })),
    },
  ];
}

function Sections({ sections }: { sections: BestForSection[] }) {
  return sections.map((section) => (
    <section key={section.heading}>
      <h2>{section.heading}</h2>
      {section.paragraphs.map((paragraph) => (
        <p key={paragraph.slice(0, 40)}>{paragraph}</p>
      ))}
    </section>
  ));
}

export function BestForPage({ content }: { content: BestForContent }) {
  return (
    <div className="doc-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(bestForJsonLd(content)) }}
      />
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <SiteHeader />

      <main className="doc" id="main">
        <nav className="breadcrumb" aria-label="Breadcrumb">
          <a href="/">Rhino</a>
          <span aria-hidden="true">/</span>
          <a href="/best">Guides</a>
          <span aria-hidden="true">/</span>
          <span>{content.label}</span>
        </nav>

        <h1>{content.headline}</h1>
        <p className="dek">{content.dek}</p>

        <aside className="answer-box">
          <h2>The short answer</h2>
          <p>{content.shortAnswer}</p>
          <ul>
            {content.shortPicks.map((entry) => (
              <li key={entry.label}>
                <strong>{entry.label}:</strong> {entry.pick}
              </li>
            ))}
          </ul>
        </aside>

        <Sections sections={content.intro} />

        {content.picks.map((pick, index) => (
          <section key={pick.name} className="pick">
            <h2>
              {index + 1}. {pick.name}
              {pick.mine ? <span className="mine-badge">mine</span> : null}
            </h2>
            <dl className="pick-meta">
              <div>
                <dt>Best for</dt>
                <dd>{pick.bestFor}</dd>
              </div>
              <div>
                <dt>Price</dt>
                <dd>{pick.price}</dd>
              </div>
              <div>
                <dt>Where your speech is processed</dt>
                <dd>{pick.where}</dd>
              </div>
            </dl>
            {pick.body.map((paragraph) => (
              <p key={paragraph.slice(0, 40)}>{paragraph}</p>
            ))}
            {pick.url ? (
              <p>
                <a
                  className="inline-link"
                  href={pick.url}
                  {...(pick.url.startsWith("http")
                    ? { target: "_blank", rel: "noopener noreferrer" }
                    : {})}
                >
                  {pick.mine ? "See what Rhino Voice does" : `Visit ${pick.name}`}
                </a>
              </p>
            ) : null}
          </section>
        ))}

        {content.outro ? <Sections sections={content.outro} /> : null}

        <section>
          <h2>Questions</h2>
          <dl className="faq">
            {content.faq.map((entry) => (
              <div key={entry.question}>
                <dt>{entry.question}</dt>
                <dd>{entry.answer}</dd>
              </div>
            ))}
          </dl>
        </section>

        <section className="doc-cta">
          <h2>Try Rhino Voice</h2>
          <p>{content.ctaBody}</p>
          <BuyForm />
        </section>

        <p className="checked-note">
          Pricing and capabilities for every app on this page checked {content.checked}.
          This field moves fast — verify current details on each site before you buy.
          Nothing here is legal, medical or compliance advice.
        </p>

        <nav className="more-links" aria-label="More guides">
          <h2>More guides</h2>
          <ul>
            {BEST_FOR_GUIDES.filter((link) => link.href !== content.slug).map((link) => (
              <li key={link.href}>
                <a href={link.href}>{link.label}</a>
              </li>
            ))}
          </ul>
          <h2>Head-to-head comparisons</h2>
          <ul>
            {COMPARISON_LINKS.map((link) => (
              <li key={link.href}>
                <a href={link.href}>{link.label}</a>
              </li>
            ))}
          </ul>
        </nav>
      </main>

      <SiteFooter />
    </div>
  );
}
