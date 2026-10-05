import type { ReactNode } from "react";
import { COMPARISON_LINKS } from "./best-for-page";
import { DownloadButton, SiteFooter, SiteHeader } from "./site-chrome";
import { type Tool, costOver, priceShort, pricesChecked } from "./competitors";

/** A tool's place on one page: shared facts plus this page's verdict. */
export type RankedEntry = {
  tool: Tool;
  bestFor: string;
  review: string[];
  badge?: string;
  /** A real app screenshot, for our own card. */
  shot?: { src: string; alt: string; caption: string; width: number; height: number };
};

export type Faq = { question: string; answer: string };

export type RankedPageContent = {
  slug: string;
  crumb: string;
  h1: string;
  quickAnswer: ReactNode;
  intro: ReactNode;
  rankedFor: string;
  entries: RankedEntry[];
  costCaption: string;
  costTools: Tool[];
  afterCards: ReactNode;
  notRanked: { tool: Tool; why: string }[];
  howWeChecked: ReactNode;
  howToSwitch: string[];
  faq: Faq[];
};

const site = "https://rhinovoice.app";

export function rankedJsonLd(content: RankedPageContent) {
  const url = `${site}${content.slug}`;
  return {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Article",
        headline: content.h1,
        url,
        author: {
          "@type": "Person",
          name: "Noah Kagan",
          jobTitle: "Founder",
          worksFor: { "@type": "Organization", name: "Rhino Voice", url: site },
        },
        publisher: { "@type": "Organization", name: "Rhino Voice", url: site },
      },
      {
        "@type": "ItemList",
        name: content.h1,
        itemListElement: content.entries.map((entry, index) => ({
          "@type": "ListItem",
          position: index + 1,
          name: entry.tool.name,
          description: entry.bestFor,
        })),
      },
      {
        "@type": "BreadcrumbList",
        itemListElement: [
          { "@type": "ListItem", position: 1, name: "Rhino", item: `${site}/` },
          { "@type": "ListItem", position: 2, name: content.crumb, item: url },
        ],
      },
      {
        "@type": "FAQPage",
        mainEntity: content.faq.map((entry) => ({
          "@type": "Question",
          name: entry.question,
          acceptedAnswer: { "@type": "Answer", text: entry.answer },
        })),
      },
    ],
  };
}

export function Byline() {
  return (
    <div className="byline">
      <div className="byline-who">
        <img src="/img/noah.jpg" alt="Noah Kagan" width={44} height={44} />
        <div>
          <div className="byline-name">Noah Kagan</div>
          <div className="byline-role">Founder, Rhino</div>
        </div>
      </div>
      <div className="byline-date">{`Prices checked ${pricesChecked}`}</div>
    </div>
  );
}

export function QuickAnswer({ children }: { children: ReactNode }) {
  return (
    <aside className="answer-box">
      <h2>Quick answer</h2>
      {children}
    </aside>
  );
}

function anchor(tool: Tool) {
  return tool.key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`);
}

export function RankTable({ entries }: { entries: RankedEntry[] }) {
  return (
    <div className="table-wrap">
      <table className="compare-table rank-table">
        <thead>
          <tr>
            <th scope="col">#</th>
            <th scope="col">App</th>
            <th scope="col">Best for</th>
            <th scope="col">Price</th>
          </tr>
        </thead>
        <tbody>
          {entries.map((entry, index) => (
            <tr key={entry.tool.key} className={entry.badge ? "rank-ours" : undefined}>
              <td data-label="Rank">{index + 1}</td>
              <th scope="row">
                <a href={`#${anchor(entry.tool)}`}>{entry.tool.name}</a>
                {entry.badge ? <span className="mine-badge">{entry.badge}</span> : null}
              </th>
              <td data-label="Best for">{entry.bestFor}</td>
              <td data-label="Price">{priceShort(entry.tool.cost)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function ToolCard({ entry, rank }: { entry: RankedEntry; rank: number }) {
  const { tool } = entry;
  const ours = Boolean(entry.badge);
  return (
    <section id={anchor(tool)} className={ours ? "tool-card tool-card-ours" : "tool-card"}>
      <h2>
        <span className="tool-num">{String(rank).padStart(2, "0")}</span> {tool.name}
        {entry.badge ? <span className="mine-badge">{entry.badge}</span> : null}
      </h2>
      <p className="tool-best">Best for: {entry.bestFor}</p>
      <dl className="pick-meta">
        <div>
          <dt>Price</dt>
          <dd>{tool.priceLine}</dd>
        </div>
        <div>
          <dt>Where your speech is processed</dt>
          <dd>{tool.where}</dd>
        </div>
      </dl>
      {entry.review.map((paragraph) => (
        <p key={paragraph.slice(0, 40)}>{paragraph}</p>
      ))}
      {entry.shot ? (
        <figure className="tool-shot">
          <img
            src={entry.shot.src}
            alt={entry.shot.alt}
            width={entry.shot.width}
            height={entry.shot.height}
            loading="lazy"
          />
          <figcaption>{entry.shot.caption}</figcaption>
        </figure>
      ) : null}
      <div className="procon">
        <div className="procon-good">
          <p>Good</p>
          <ul>
            {tool.good.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </div>
        <div className="procon-bad">
          <p>Not so good</p>
          <ul>
            {tool.bad.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </div>
      </div>
      <div className="tool-links">
        {ours ? <DownloadButton /> : null}
        {tool.site ? (
          <a className="inline-link" href={tool.site} target="_blank" rel="nofollow noopener noreferrer">
            {tool.name} website ↗
          </a>
        ) : null}
        {tool.vs ? (
          <a className="inline-link" href={tool.vs}>
            Rhino Voice vs {tool.name}
          </a>
        ) : null}
      </div>
    </section>
  );
}

export function CostTable({ caption, tools }: { caption: string; tools: Tool[] }) {
  return (
    <div className="table-wrap">
      <table className="compare-table">
        <caption>{caption}</caption>
        <thead>
          <tr>
            <th scope="col">App</th>
            <th scope="col">Price</th>
            <th scope="col">1 year</th>
            <th scope="col">3 years</th>
          </tr>
        </thead>
        <tbody>
          {tools.map((tool) => (
            <tr key={tool.key}>
              <th scope="row">{tool.name}</th>
              <td data-label="Price">{priceShort(tool.cost)}</td>
              <td data-label="1 year">{costOver(tool.cost, 1)}</td>
              <td data-label="3 years">{costOver(tool.cost, 3)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

export function RankedPage({ content }: { content: RankedPageContent }) {
  return (
    <div className="doc-page">
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(rankedJsonLd(content)) }}
      />
      <a className="skip-link" href="#main">
        Skip to content
      </a>

      <SiteHeader />

      <main className="doc" id="main">
        <nav className="breadcrumb" aria-label="Breadcrumb">
          <a href="/">Rhino</a>
          <span aria-hidden="true">/</span>
          <span>{content.crumb}</span>
        </nav>

        <h1>{content.h1}</h1>
        <Byline />
        <QuickAnswer>{content.quickAnswer}</QuickAnswer>

        <div className="top-cta">
          <DownloadButton />
          <span>Free to start. Unlimited is $20 once.</span>
        </div>

        <div className="intro">{content.intro}</div>

        <RankTable entries={content.entries} />
        <p className="checked-note">Ranked for {content.rankedFor}.</p>

        {content.entries.map((entry, index) => (
          <ToolCard key={entry.tool.key} entry={entry} rank={index + 1} />
        ))}

        <section>
          <h2>What each costs over time</h2>
          <CostTable caption={content.costCaption} tools={content.costTools} />
          <p className="checked-note">
            Prices from each app&apos;s own site, checked {pricesChecked}. Yearly costs use
            the annual rate where one exists. &quot;About&quot; means the vendor lists an
            approximate or non-dollar price.
          </p>
        </section>

        {content.afterCards}

        <section>
          <h2>Checked, but not ranked</h2>
          {content.notRanked.map(({ tool, why }) => (
            <p key={tool.key}>
              <strong>{tool.name}.</strong> {why}
            </p>
          ))}
        </section>

        <section>
          <h2>How we checked</h2>
          {content.howWeChecked}
        </section>

        <section>
          <h2>How to switch</h2>
          <ol className="switch-steps">
            {content.howToSwitch.map((step) => (
              <li key={step}>{step}</li>
            ))}
          </ol>
        </section>

        <section>
          <h2>Questions people ask</h2>
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
            Free to start: unlimited your first week, then 2,000 words a week. Unlimited is $20 once, no subscription and no account.
          </p>
          <DownloadButton />
        </section>

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

        <p className="checked-note">
          All trademarks belong to their owners and are used here for comparison only.
        </p>
      </main>

      <SiteFooter />
    </div>
  );
}
