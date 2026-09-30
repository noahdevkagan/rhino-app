# Site playbook — MeetMouse & Rhino Voice

One set of rules for the marketing pages on **meetmouse.com** and **rhinovoice.app**.
Both repos carry an identical copy of this file; change it in one, copy it to the other.
It's for agents and humans writing "best X for Y" guides, "vs" pages, "alternatives"
pages and blog posts.

## 1. Before you write: check what already exists

- **One page per search intent.** Before adding a page, list the existing pages and ask
  "would someone searching this land happily on a page we already have?" If yes, improve
  that page instead. (MeetMouse cut nine drafts for this: "Fathom without a bot" duplicated
  `blog/ai-notetaker-without-bot`, "private Granola alternative" duplicated
  `blog/private-ai-meeting-notes`, etc.)
- **"Us vs X" beats "X vs Y".** New head-to-heads are "MeetMouse vs X" / "Rhino Voice vs X".
  Third-party "X vs Y" pages are allowed as traffic plays, but they must end with a section
  that pitches our app ("The part neither fixes").
- **Sell the right product.** If the reader's job is meetings, the page sells MeetMouse; if
  it's dictation, Rhino Voice. (Rhino's Otter-alternatives page leads with MeetMouse.)

## 2. Voice

Noah's voice, first person. The live posts are the reference.

- Disclose the bias in the first line: "Full disclosure: I make X."
- Contractions, American spelling, short sentences, plain words. No "leverage", "robust",
  "seamless", "in today's fast-paced world".
- Concede real wins. If a competitor is better for this reader, say so plainly, and put it
  first when it's the right pick. Pages that always crown their author don't get quoted.
- **No invented anecdotes.** Personal claims are limited to what's true: Noah built the app,
  founded AppSumo and SumoMe, builds with AI coding agents. No made-up "I lost a deal at
  minute nine" stories. If a story would help, leave a `TODO(noah): real story` and ask.
- Every page ends in something to *do*: "My pick" plus "What I'd do today" (mostly free steps).
- Refund line, same words everywhere: "$20 once … If it doesn't …, email me within 30 days
  and I'll refund you."

## 3. Facts and claims

- **Our product:** only claim what the homepage/code says. MeetMouse: transcription on the
  Mac; AI local by default, optional own Claude/OpenAI key; no bot; notes + chat + live
  coaching; Mac only, macOS 14.2+, Apple Silicon recommended. Rhino Voice: on-device only,
  Apple Silicon, macOS 14+.
- **Competitors:** reuse prices already verified on the site. If a price isn't verified,
  describe it without a number ("free tier; paid plans monthly", "custom enterprise pricing").
- Every guide and comparison shows **the month its claims were checked** and tells readers
  to double-check. Re-check when you touch a page.
- No compliance claims (HIPAA, SOC 2, legal ethics) for our apps. Say "I'm not your lawyer,
  doctor or compliance officer."

## 4. Page anatomy

All content pages share one template per site (MeetMouse: `site/build.py`; Rhino:
`website/app/_components/*-page.tsx`). Never hand-write a page's chrome.

**Guide (`/best/<x>`)**: breadcrumb → h1 "The best … (2026)" → dek (disclosure) →
TL;DR box (one liftable paragraph + 3–4 "Best for …: pick" bullets) → "picks at a glance"
table → optional framing sections → numbered picks, each with a Best for / Price / Where
it runs box, ours marked **mine** → My pick → What I'd do today → Questions → buy box →
checked-on note → More guides / Comparisons links.

**Comparison (`/compare/…` on MeetMouse, `/vs/…` on Rhino)**: breadcrumb → h1 → dek →
"The short answer" box with "Pick X if … / Pick us if …" → table with **our column
first** → where they win → where we win → verdict → Questions → buy box → checked-on
note → more links.

**Hubs** (`/best/`, comparisons hub, blog index): short dek in the same voice, then
cards. Every hub also links to the sister site's matching hub.

## 5. Cross-linking

- **One list drives everything.** Each site keeps a single list of its pages
  (MeetMouse `site/content/links.py` + `best.py` + `compare.py`; Rhino `BEST_FOR_GUIDES`
  and `COMPARISON_LINKS`). Hubs, "More guides" blocks, llms.txt and checks read from it,
  so a page can't ship unlinked.
- **Every content page links out to:** its hub (breadcrumb), all sibling guides, all
  comparisons, and 2–4 in-body links where they genuinely help ("My full comparison").
- **Anchor text says where it goes** ("MeetMouse vs Gong", "Best AI notetaker for
  lawyers"), never "click here".
- **Cross-site:** footers link the sister app; guide hubs link each other's guide hub;
  a guide whose reader also has the other job adds the sister app as a disclosed "mine"
  pick or one in-body line (e.g. Rhino's Otter page → MeetMouse; MeetMouse guides for
  lawyers/consultants → Rhino for dictating memos). Never more than one sister-app
  mention per page.
- External competitor links: only to their homepage, `rel="noopener"`.

## 6. Search & answer engines

- Title ≤ ~65 chars with the year: "Best AI Notetaker for Lawyers (2026): …".
  Meta description ≤ ~160 chars, states the angle.
- JSON-LD on every page: BreadcrumbList; ItemList for guides and hubs; FAQPage for any
  page with Questions; Article for blog posts.
- The TL;DR / short answer must stand alone — that's the paragraph assistants quote.
- Sitemap and llms.txt list every page (both generated/checked from the page list).

## 7. Shipping

- Build + check before pushing. MeetMouse: `python3 site/build.py` then
  `python3 site/build.py --check` (links, JSON-LD, stale output, sitemap, "mine" pick).
  Rhino: `npm test` in `website/`.
- Both sites deploy on push to the default branch when site files change
  (MeetMouse `.github/workflows/deploy-site.yml`, Rhino `deploy-website.yml`).
- Log non-obvious choices in `decisions.md`.

## 8. Shared design

Same design system on both sites: paper `#fbf8f4`, ink `#171514`, muted `#69635f`,
line `#e5ded8`, Geist. Accent is the only difference — Rhino coral `#ff705f`,
MeetMouse green `#2bbd3e`. Doc column 760px; header 1180px.
