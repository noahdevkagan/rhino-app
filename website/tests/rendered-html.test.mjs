import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render(path = "/") {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${path}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(new URL(path, "https://rhinovoice.app"), {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("server-renders the concise PayPal purchase page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Rhino Voice — Private dictation for Mac<\/title>/i);
  assert.match(html, /Talk\. Rhino types\./);
  assert.match(html, /Nothing leaves your Mac\./);
  assert.match(html, /Buy Rhino — \$20/);
  assert.match(html, /action="https:\/\/www\.paypal\.com\/cgi-bin\/webscr"/);
  assert.match(html, /name="business" value="paypal@okdork\.com"/);
  assert.match(html, /name="item_name" value="Rhino for Mac"/);
  assert.match(html, /name="amount" value="20\.00"/);
  assert.match(html, /name="return" value="https:\/\/rhinovoice\.app\/thanks"/);
  assert.match(html, /30-day money-back guarantee/);
  assert.match(html, /href="\/changelog"/);
  assert.match(html, /https:\/\/rhinovoice\.app\/og\.png/);
});

test("carries the below-the-fold SEO sections without disturbing the hero", async () => {
  const response = await render();
  const html = await response.text();

  // The hero is still the first thing in <main> and still one screen (see
  // decisions.md 2026-09-17). These sections live below it, not inside it.
  assert.match(html, /<main class="hero" id="main">/);
  assert.match(html, /class="below-fold"/);
  assert.ok(html.indexOf('class="below-fold"') > html.indexOf('<main class="hero"'));

  assert.match(html, /Three keys, one sentence/);
  assert.match(html, /What you get for \$20/);
  assert.match(html, /How Rhino Voice compares/);
  assert.match(html, /Stop typing what you could have said\./);

  // FAQ answers are the text AI assistants quote; keep them in the HTML.
  assert.match(html, /Does my voice or my text leave my Mac\?/);
  assert.match(html, /An Apple silicon Mac running macOS 14 or later/);
  assert.match(html, /"@type":"FAQPage"/);
  assert.match(html, /"@type":"SoftwareApplication"/);
  assert.match(html, /"name":"Rhino Voice"/);

  // Every comparison page is reachable from the homepage.
  for (const href of [
    "/vs/wispr-flow",
    "/vs/superwhisper",
    "/vs/macwhisper",
    "/vs/apple-dictation",
    "/alternatives/wispr-flow",
    "/alternatives/dragon",
    "/alternatives/superwhisper",
    "/alternatives/macwhisper",
    "/alternatives/otter",
  ]) {
    assert.match(html, new RegExp(`href="${href}"`));
  }
});

test("renders every comparison page with its schema and canonical", async () => {
  const routes = [
    ["/vs/wispr-flow", /Rhino Voice vs Wispr Flow/, /\$15\/month/],
    ["/vs/superwhisper", /Rhino Voice vs superwhisper/, /no cloud pathway/],
    ["/vs/macwhisper", /Rhino Voice vs MacWhisper/, /file transcription|transcribing/i],
    ["/vs/apple-dictation", /Rhino Voice vs Apple Dictation/, /transcribes you literally/],
    ["/alternatives/wispr-flow", /Wispr Flow alternatives/, /superwhisper/],
    ["/alternatives/superwhisper", /superwhisper alternatives/, /VoiceInk/],
    ["/alternatives/macwhisper", /MacWhisper alternatives/, /Aiko/],
    ["/alternatives/otter", /Otter\.ai alternatives/, /MeetMouse/],
  ];

  for (const [path, headline, body] of routes) {
    const response = await render(path);
    assert.equal(response.status, 200, `${path} should render`);

    const html = await response.text();
    assert.match(html, headline, `${path} headline`);
    assert.match(html, body, `${path} body`);
    assert.match(html, /"@type":"FAQPage"/, `${path} FAQ schema`);
    assert.match(html, /"@type":"BreadcrumbList"/, `${path} breadcrumb schema`);
    assert.match(
      html,
      new RegExp(`rel="canonical" href="https://rhinovoice\\.app${path}"`),
      `${path} canonical`,
    );
    // Every page keeps a working buy path.
    assert.match(html, /name="amount" value="20\.00"/, `${path} buy form`);
  }
});

test("renders every best-for guide with its schema, canonical and disclosure", async () => {
  const guides = [
    ["/best/dictation-app-for-lawyers", /dictation app for lawyers/, /privilege/i],
    ["/best/dictation-app-for-doctors", /dictation app for doctors/, /ambient/i],
    ["/best/dictation-app-for-writers", /dictation app for writers/, /Scrivener/],
    ["/best/dictation-app-for-developers", /dictation app for developers/, /Talon/],
    ["/best/dictation-app-for-adhd", /dictation app for ADHD/, /friction/i],
    ["/best/dictation-app-for-rsi", /RSI and carpal tunnel/, /Voice Control/],
    ["/best/dictation-app-for-students", /dictation app for students/, /Google Docs voice typing/],
    ["/best/dictation-app-for-non-native-english-speakers", /non-native English speakers/, /Parakeet v3/],
    ["/best/dictation-app-for-journalists", /apps for journalists/, /MacWhisper/],
    ["/best/offline-dictation-app-for-mac", /offline dictation app for Mac/, /Wi-Fi off/],
  ];

  const sitemap = await readFile(new URL("../public/sitemap.xml", import.meta.url), "utf8");
  assert.match(sitemap, /<loc>https:\/\/rhinovoice\.app\/best<\/loc>/);
  const hub = await (await render("/best")).text();
  const home = await (await render("/")).text();
  assert.match(home, /href="\/best"/);

  for (const [path, headline, body] of guides) {
    const response = await render(path);
    assert.equal(response.status, 200, `${path} should render`);

    const html = await response.text();
    assert.match(html, headline, `${path} headline`);
    assert.match(html, body, `${path} body`);
    assert.match(html, /"@type":"FAQPage"/, `${path} FAQ schema`);
    assert.match(html, /"@type":"ItemList"/, `${path} list schema`);
    assert.match(html, /"@type":"BreadcrumbList"/, `${path} breadcrumb schema`);
    assert.match(
      html,
      new RegExp(`rel="canonical" href="https://rhinovoice\\.app${path}"`),
      `${path} canonical`,
    );
    // Rhino appears on every guide and is always disclosed as the author's own.
    assert.match(html, /class="mine-badge"/, `${path} discloses Rhino is mine`);
    assert.match(html, /name="amount" value="20\.00"/, `${path} buy form`);
    assert.match(hub, new RegExp(`href="${path}"`), `${path} listed on /best`);
    assert.ok(sitemap.includes(`<loc>https://rhinovoice.app${path}</loc>`), `${path} in sitemap`);
  }
});

test("cross-links the sister site per SITE-PLAYBOOK.md", async () => {
  const hub = await (await render("/best")).text();
  assert.match(hub, /href="https:\/\/meetmouse\.com\/best\/"/);

  const lawyers = await (await render("/best/dictation-app-for-lawyers")).text();
  assert.match(lawyers, /href="https:\/\/meetmouse\.com\/best\/ai-notetaker-for-lawyers"/);
});

test("labels table cells so phones can stack rows into cards", async () => {
  const guide = await (await render("/best/dictation-app-for-lawyers")).text();
  assert.match(guide, /<td data-label="Price">/);
  const vs = await (await render("/vs/wispr-flow")).text();
  assert.match(vs, /<td data-label="Rhino Voice">/);
});

test("renders the changelog and post-purchase download routes", async () => {
  const [changelogResponse, thanksResponse] = await Promise.all([
    render("/changelog"),
    render("/thanks"),
  ]);

  assert.equal(changelogResponse.status, 200);
  assert.equal(thanksResponse.status, 200);
  const [changelog, thanks] = await Promise.all([
    changelogResponse.text(),
    thanksResponse.text(),
  ]);

  assert.match(changelog, /<h1>Changelog<\/h1>/);
  // The changelog has its own title, not a copy of the homepage's.
  assert.match(changelog, /<title>Rhino Voice Changelog/);
  assert.match(changelog, /rel="canonical" href="https:\/\/rhinovoice\.app\/changelog"/);
  assert.match(changelog, /0\.1\.9/);
  assert.match(changelog, /downloads the on-device cleanup model automatically/);
  assert.match(changelog, /Smart formatting/);
  assert.match(changelog, /Finished dictations now appear sooner/);
  assert.match(changelog, /oversized keyboard diagram/);
  assert.match(changelog, /high-resolution artwork/);
  assert.match(changelog, /permission loop/);
  assert.match(changelog, /updates itself automatically/);
  assert.match(thanks, /Thanks for buying Rhino/);
  assert.match(thanks, /Rhino-0\.1\.31\.dmg/);
  assert.match(thanks, /Download Rhino for Mac/);
});

test("ships the crisp Rhino favicon and product metadata", async () => {
  const [page, chrome, layout, packageJson, favicon, socialCard] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/_components/site-chrome.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../app/icon.png", import.meta.url)),
    readFile(new URL("../public/og.png", import.meta.url)),
  ]);

  // The visible logo renders the system rhino emoji, never the cropped app
  // icon bitmap (decisions.md 2026-08-11). It now lives in the shared chrome.
  assert.match(chrome, /🦏/);
  assert.doesNotMatch(chrome, /\/rhino-icon\.png/);
  assert.doesNotMatch(page, /\/rhino-icon\.png/);
  assert.match(layout, /new URL\("\/og\.png", baseUrl\)/);
  assert.doesNotMatch(layout, /rhino-mark\.png/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.ok(favicon.byteLength > 20_000);
  assert.ok(socialCard.byteLength > 100_000);
});

test("advertises the Rhino favicon in rendered HTML", async () => {
  const response = await render();
  const html = await response.text();

  assert.match(
    html,
    /<link rel="icon" href="https:\/\/rhinovoice\.app\/icon\.png[^\"]*"/i,
  );
});

test("renders the AppSumo redemption route", async () => {
  const response = await render("/appsumo");
  assert.equal(response.status, 200);

  const html = await response.text();
  assert.match(html, /Redeem your Rhino code/);
  assert.match(html, /AppSumo purchase/);
  assert.match(html, /RH-XXXX-XXXX-XXXX/);
  assert.match(html, /Getting ready…/);
  assert.match(html, /noahkagan@gmail\.com/);
  assert.match(
    await readFile(new URL("../app/appsumo/redeem-form.tsx", import.meta.url), "utf8"),
    /Rhino-0\.1\.31\.dmg/,
  );
  assert.match(html, /name="robots" content="noindex, nofollow"/i);
});

test("ships exactly 10,000 unique, well-formed redemption hashes", async () => {
  const payload = await readFile(
    new URL("../public/appsumo-hashes.json", import.meta.url),
    "utf8",
  );
  const hashes = JSON.parse(payload);

  assert.equal(hashes.length, 10_000);
  assert.equal(new Set(hashes).size, 10_000);
  assert.ok(hashes.every((hash) => /^[a-f0-9]{64}$/.test(hash)));
  assert.deepEqual(hashes, [...hashes].sort());
});

test("generates AppSumo codes whose hashes match the published format", async () => {
  const { generateCodeBatch, hashCode } = await import(
    "../scripts/generate-appsumo-codes.mjs"
  );
  const codes = generateCodeBatch(100);

  assert.equal(new Set(codes).size, 100);
  assert.ok(codes.every((code) => /^RH-[A-HJ-NP-Z2-9]{4}(?:-[A-HJ-NP-Z2-9]{4}){2}$/.test(code)));
  assert.ok(codes.every((code) => hashCode(code) === createHash("sha256").update(code).digest("hex")));
});
