import { COMPARISON_LINKS } from "./best-for-page";
import { DownloadButton, SiteFooter, SiteHeader } from "./site-chrome";

/**
 * Competitor-vs-competitor pages (/compare/a-vs-b): a fair head-to-head of two
 * apps we don't make, then one section on where Rhino fits. People searching
 * "X vs Y" are about to pick a dictation app, so the download sits in the top third.
 */
export type HeadToHeadRow = { label: string; a: string; b: string };

export type HeadToHeadSection = { heading: string; paragraphs: string[] };

export type HeadToHeadContent = {
  slug: string;
  a: string;
  b: string;
  headline: string;
  dek: string;
  /** The paragraph an AI assistant should be able to lift verbatim. */
  shortAnswer: string;
  pickA: string;
  pickB: string;
  rows: HeadToHeadRow[];
  sections: HeadToHeadSection[];
  /** "The part neither fixes" (SITE-PLAYBOOK §1): who should skip both, and why Rhino. */
  rhinoFit: string[];
  faq: { question: string; answer: string }[];
  /** Official pages the prices and claims came from, as plain text (no deep links, §5). */
  sources: string[];
  /** Month + year the prices and claims were last checked. */
  checked: string;
};

function label(content: HeadToHeadContent) {
  return `${content.a} vs ${content.b}`;
}

export function headToHeadJsonLd(content: HeadToHeadContent) {
  const url = `https://rhinovoice.app${content.slug}`;
  return [
    {
      "@context": "https://schema.org",
      "@type": "BreadcrumbList",
      itemListElement: [
        { "@type": "ListItem", position: 1, name: "Rhino", item: "https://rhinovoice.app/" },
        { "@type": "ListItem", position: 2, name: label(content), item: url },
      ],
    },
    {
      "@context": "https://schema.org",
      "@type": "Article",
      headline: content.headline,
      url,
      author: { "@type": "Person", name: "Noah Kagan", url: "https://noahkagan.com/" },
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

export function HeadToHeadPage({ content }: { content: HeadToHeadContent }) {
  return (
    <div className="doc-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(headToHeadJsonLd(content)) }}
      />
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <SiteHeader />

      <main className="doc" id="main">
        <nav className="breadcrumb" aria-label="Breadcrumb">
          <a href="/">Rhino</a>
          <span aria-hidden="true">/</span>
          <span>{label(content)}</span>
        </nav>

        <h1>{content.headline}</h1>
        <p className="dek">{content.dek}</p>

        <div className="byline">
          <div className="byline-who">
            <img src="/img/noah.jpg" alt="Noah Kagan" width={44} height={44} />
            <div>
              <div className="byline-name">Noah Kagan</div>
              <div className="byline-role">Founder, Rhino (I make neither of these apps)</div>
            </div>
          </div>
          <div className="byline-date">{`Prices checked ${content.checked}`}</div>
        </div>

        <aside className="answer-box">
          <h2>The short answer</h2>
          <p>{content.shortAnswer}</p>
          <ul>
            <li>
              <strong>Pick {content.a} if</strong> {content.pickA}
            </li>
            <li>
              <strong>Pick {content.b} if</strong> {content.pickB}
            </li>
          </ul>
        </aside>

        <div className="top-cta">
          <p>
            Or skip both: Rhino Voice is free, runs entirely on your Mac and needs no account.
          </p>
          <DownloadButton />
        </div>

        <div className="table-wrap">
          <table className="compare-table">
            <caption>{label(content)} at a glance</caption>
            <thead>
              <tr>
                <th scope="col">&nbsp;</th>
                <th scope="col">{content.a}</th>
                <th scope="col">{content.b}</th>
              </tr>
            </thead>
            <tbody>
              {content.rows.map((row) => (
                <tr key={row.label}>
                  <th scope="row">{row.label}</th>
                  <td data-label={content.a}>{row.a}</td>
                  <td data-label={content.b}>{row.b}</td>
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
          <h2>The part neither fixes</h2>
          {content.rhinoFit.map((paragraph) => (
            <p key={paragraph.slice(0, 40)}>{paragraph}</p>
          ))}
        </section>

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
            Free to start: unlimited your first week, then 2,000 words a week. Unlimited is $20
            once, no subscription and no account. If it doesn&apos;t save you time, email me
            within 30 days and I&apos;ll refund you.
          </p>
          <DownloadButton />
        </section>

        <p className="checked-note">
          I checked both apps&apos; prices and claims on their own sites in {content.checked}.
          Dictation apps change pricing often, so confirm on their sites before you buy.{" "}
          {content.a} and {content.b} are trademarks of their owners. Rhino isn&apos;t
          affiliated with either.
        </p>
        <ul className="sources" aria-label="Where these facts come from">
          {content.sources.map((source) => (
            <li key={source}>{source}</li>
          ))}
        </ul>

        <nav className="more-links" aria-label="More comparisons">
          <h2>More comparisons</h2>
          <ul>
            {COMPARISON_LINKS.filter((link) => link.href !== content.slug).map((link) => (
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
