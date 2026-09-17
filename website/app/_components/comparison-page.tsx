import { BuyForm, SiteFooter, SiteHeader } from "./site-chrome";

export type ComparisonRow = {
  label: string;
  rhino: string;
  them: string;
};

export type ComparisonSection = {
  heading: string;
  paragraphs: string[];
};

export type ComparisonFaq = {
  question: string;
  answer: string;
};

export type ComparisonContent = {
  slug: string;
  competitor: string;
  headline: string;
  dek: string;
  /** The two-sentence answer an AI assistant should be able to lift verbatim. */
  shortAnswer: string;
  pickThem: string;
  pickRhino: string;
  tableCaption: string;
  rows: ComparisonRow[];
  sections: ComparisonSection[];
  faq: ComparisonFaq[];
  /** Month + year the competitor's pricing and claims were last checked. */
  checked: string;
};

const OTHER_LINKS: { href: string; label: string }[] = [
  { href: "/vs/wispr-flow", label: "Rhino Voice vs Wispr Flow" },
  { href: "/vs/superwhisper", label: "Rhino Voice vs superwhisper" },
  { href: "/vs/macwhisper", label: "Rhino Voice vs MacWhisper" },
  { href: "/vs/apple-dictation", label: "Rhino Voice vs Apple Dictation" },
  { href: "/alternatives/wispr-flow", label: "Wispr Flow alternatives" },
];

export function comparisonJsonLd(content: ComparisonContent) {
  const url = `https://rhinovoice.app${content.slug}`;

  return [
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Rhino", item: "https://rhinovoice.app/" },
        { "@type": "ListItem", position: 2, name: content.headline, item: url },
      ],
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

export function ComparisonPage({ content }: { content: ComparisonContent }) {
  return (
    <div className="doc-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(comparisonJsonLd(content)) }}
      />
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <SiteHeader />

      <main className="doc" id="main">
        <nav className="breadcrumb" aria-label="Breadcrumb">
          <a href="/">Rhino</a>
          <span aria-hidden="true">/</span>
          <span>vs {content.competitor}</span>
        </nav>

        <h1>{content.headline}</h1>
        <p className="dek">{content.dek}</p>

        <aside className="answer-box">
          <h2>The short answer</h2>
          <p>{content.shortAnswer}</p>
          <ul>
            <li>
              <strong>Pick {content.competitor} if</strong> {content.pickThem}
            </li>
            <li>
              <strong>Pick Rhino Voice if</strong> {content.pickRhino}
            </li>
          </ul>
        </aside>

        <div className="table-wrap">
          <table className="compare-table">
            <caption>{content.tableCaption}</caption>
            <thead>
              <tr>
                <th scope="col">&nbsp;</th>
                <th scope="col">Rhino Voice</th>
                <th scope="col">{content.competitor}</th>
              </tr>
            </thead>
            <tbody>
              {content.rows.map((row) => (
                <tr key={row.label}>
                  <th scope="row">{row.label}</th>
                  <td>{row.rhino}</td>
                  <td>{row.them}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        {content.sections.map((section) => (
          <section key={section.heading}>
            <h2>{section.heading}</h2>
            {section.paragraphs.map((paragraph) => (
              <p key={paragraph.slice(0, 40)}>{paragraph}</p>
            ))}
          </section>
        ))}

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
          <p>
            $20 once, no subscription and no account. If it does not earn its keep,
            email me inside 30 days and I will refund you.
          </p>
          <BuyForm />
        </section>

        <p className="checked-note">
          {content.competitor} pricing and capabilities checked {content.checked}.
          Competitors ship fast — verify current details on their site before you buy
          either one.
        </p>

        <nav className="more-links" aria-label="More comparisons">
          <h2>More comparisons</h2>
          <ul>
            {OTHER_LINKS.filter((link) => link.href !== content.slug).map((link) => (
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
