import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

async function render() {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request("https://rhinovoice.app/", {
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

test("server-renders the Rhino launch page", async () => {
  const response = await render();
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /<title>Rhino — Private dictation for Mac<\/title>/i);
  assert.match(html, /Talk\. Rhino types\./);
  assert.match(html, /Nothing leaves your Mac\./);
  assert.match(html, /Download Rhino for Mac/);
  assert.match(html, /Rhino-0\.1\.2\.dmg/);
  assert.match(html, /Private by design/);
  assert.match(html, /https:\/\/rhinovoice\.app\/og\.png/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape/);
});

test("ships the product assets and removes starter dependencies", async () => {
  const [page, layout, packageJson, icon, socialCard] = await Promise.all([
    readFile(new URL("../app/page.tsx", import.meta.url), "utf8"),
    readFile(new URL("../app/layout.tsx", import.meta.url), "utf8"),
    readFile(new URL("../package.json", import.meta.url), "utf8"),
    readFile(new URL("../public/rhino-icon.png", import.meta.url)),
    readFile(new URL("../public/og.png", import.meta.url)),
  ]);

  assert.match(page, /macOS 14\+/);
  assert.match(page, /Apple silicon/);
  assert.match(layout, /new URL\("\/og\.png", baseUrl\)/);
  assert.doesNotMatch(packageJson, /react-loading-skeleton/);
  assert.ok(icon.byteLength > 10_000);
  assert.ok(socialCard.byteLength > 100_000);
});
