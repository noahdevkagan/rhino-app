import assert from "node:assert/strict";
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
  assert.match(html, /<title>Rhino — Private dictation for Mac<\/title>/i);
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
  assert.doesNotMatch(html, /Built for everyday writing|Up and running in minutes|Good things to know/);
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
  assert.match(changelog, /0\.1\.2/);
  assert.match(changelog, /updates itself automatically/);
  assert.match(thanks, /Thanks for buying Rhino/);
  assert.match(thanks, /Rhino-0\.1\.2\.dmg/);
  assert.match(thanks, /Download Rhino for Mac/);
});

test("ships the crisp brand asset and product metadata", async () => {
  const [page, layout, packageJson, mark, socialCard] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../public/rhino-mark.png", import.meta.url)),
    readFile(new URL("../public/og.png", import.meta.url)),
  ]);

  assert.match(page, /🦏/);
  assert.doesNotMatch(page, /\/rhino-icon\.png/);
  assert.match(layout, /new URL\("\/og\.png", baseUrl\)/);
  assert.match(layout, /icon: "\/rhino-mark\.png"/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.ok(mark.byteLength > 50_000);
  assert.ok(socialCard.byteLength > 100_000);
});
