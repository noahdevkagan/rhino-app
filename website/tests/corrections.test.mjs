import assert from "node:assert/strict";
import { DatabaseSync } from "node:sqlite";
import test from "node:test";
import { isAdmin, parseCorrectionReport, scrubPair } from "../app/_lib/corrections.ts";

const id = (n) => `00000000-0000-4000-8000-${String(n).padStart(12, "0")}`;
const report = (n, items) => ({ installId: id(n), appVersion: "0.1.44", items });
const pair = (heard, corrected) => ({ heard, corrected, engine: "whisper", model: "ggml-base.en", language: "en" });

test("keeps ordinary fixes and collapses whitespace", () => {
  assert.deepEqual(scrubPair(" git   hub ", "GitHub"), { heard: "git hub", corrected: "GitHub" });
  assert.deepEqual(scrubPair("Clavio", "Klaviyo"), { heard: "Clavio", corrected: "Klaviyo" });
});

test("drops anything personal-looking, long, empty or identical (same rules as the app)", () => {
  for (const [h, c] of [
    ["noah at gmail", "noah@gmail.com"],
    ["site", "https://example.org"],
    ["site", "www.example"],
    ["rhino voice dot app", "rhinovoice.app"],
    ["pin", "4321"],
    ["card", "4111 1111"],
    ["phone", "555-1234"],
    ["key", "sk-abc123"],
    ["token", "ghp_abcdef"],
    ["id", "a1b2c3d4e5f6g7h8"],
    ["blob", "abcdefghijklmnopqrstuvwxyz"],
    ["one two three four five six", "x"],
    ["", "Klaviyo"],
    ["Klaviyo", "Klaviyo"],
    ["!!", "?"],
    ["tag", "<script>"],
    ["a".repeat(61), "b"],
  ]) {
    assert.equal(scrubPair(h, c), null, `${h} → ${c}`);
  }
});

test("validates the envelope, drops bad pairs and unknown fields", () => {
  assert.equal(parseCorrectionReport({ installId: "nope", items: [pair("a", "b")] }), null);
  assert.equal(parseCorrectionReport(report(1, [])), null);
  assert.equal(parseCorrectionReport(report(1, Array(101).fill(pair("Clavio", "Klaviyo")))), null);
  assert.equal(parseCorrectionReport(report(1, [pair("pin", "4321")])), null, "an all-bad batch is rejected");

  const r = parseCorrectionReport({
    ...report(1, [
      { ...pair("Clavio", "Klaviyo"), text: "secret dictation", app: "Messages" },
      pair("clavio", "Klaviyo"),
      pair("pin", "4321"),
      { ...pair("git hub", "GitHub"), model: "/Users/noah/secret model.bin", language: "english please" },
    ]),
    transcript: "secret",
  });
  assert.equal(r.items.length, 2, "duplicate and personal pairs are dropped");
  assert.ok(!JSON.stringify(r).includes("secret"));
  assert.ok(!JSON.stringify(r).includes("Messages"));
  assert.equal(r.items[1].model, "");
  assert.equal(r.items[1].language, "");
});

test("admin check needs a long configured token and an exact bearer match", () => {
  const token = "t".repeat(40);
  const req = (auth) => new Request("https://rhinovoice.app/x", { headers: auth ? { authorization: auth } : {} });
  assert.equal(isAdmin(req(`Bearer ${token}`), token), true);
  assert.equal(isAdmin(req(`Bearer ${token}x`), token), false);
  assert.equal(isAdmin(req(), token), false);
  assert.equal(isAdmin(req("Bearer short"), "short"), false, "short secrets are refused outright");
  assert.equal(isAdmin(req(`Bearer ${token}`), undefined), false);
});

/** Minimal D1 over node:sqlite: enough of prepare/bind/run/all/first/batch for these routes. */
function fakeD1() {
  const sqlite = new DatabaseSync(":memory:");
  const stmt = (sql, args = []) => ({
    sql,
    args,
    bind: (...a) => stmt(sql, a),
    run: async () => (sqlite.prepare(sql).run(...args), { success: true }),
    all: async () => ({ results: sqlite.prepare(sql).all(...args) }),
    first: async () => sqlite.prepare(sql).get(...args) ?? null,
  });
  return {
    sqlite,
    prepare: (sql) => stmt(sql),
    batch: async (list) => Promise.all(list.map((s) => s.run())),
  };
}

async function worker() {
  const url = new URL("../dist/server/index.js", import.meta.url);
  url.searchParams.set("test", `corrections-${process.pid}-${Date.now()}`);
  return (await import(url.href)).default;
}

test("end to end: post, summary threshold, opt-out delete, 180-day purge", async () => {
  const w = await worker();
  const db = fakeD1();
  const token = "s".repeat(48);
  const env = { ASSETS: { fetch: async () => new Response("", { status: 404 }) }, REFERRALS: db, ADMIN_TOKEN: token };
  const ctx = { waitUntil() {}, passThroughOnException() {} };
  const call = (method, path, body, headers = {}) =>
    w.fetch(
      new Request(new URL(path, "https://rhinovoice.app"), {
        method,
        headers: { "content-type": "application/json", ...headers },
        body: body ? JSON.stringify(body) : undefined,
      }),
      env,
      ctx,
    );
  const summary = async () => (await (await call("GET", "/api/admin/corrections-summary", null, { authorization: `Bearer ${token}` })).json()).pairs;

  assert.equal((await call("POST", "/api/corrections", { nope: 1 })).status, 400);
  assert.equal((await call("GET", "/api/admin/corrections-summary")).status, 401);

  // Klaviyo from 3 Macs (one twice), GitHub from 2: only Klaviyo clears the 3-install bar.
  for (const n of [1, 2, 3]) assert.equal((await call("POST", "/api/corrections", report(n, [pair("Clavio", "Klaviyo")]))).status, 204);
  assert.equal((await call("POST", "/api/corrections", report(1, [pair("clavio", "Klaviyo")]))).status, 204);
  for (const n of [1, 2]) await call("POST", "/api/corrections", report(n, [pair("git hub", "GitHub")]));

  let pairs = await summary();
  assert.equal(pairs.length, 1);
  assert.equal(pairs[0].corrected, "Klaviyo");
  assert.equal(pairs[0].installs, 3);
  assert.ok(!JSON.stringify(pairs).includes(id(1)), "the summary never carries install IDs");

  // Opt-out from one Mac drops Klaviyo under the bar.
  assert.equal((await call("DELETE", `/api/corrections?installId=${id(3)}`)).status, 204);
  assert.equal((await call("DELETE", "/api/corrections?installId=bad")).status, 400);
  assert.equal((await summary()).length, 0);

  // Rows older than 180 days are purged on the next read.
  await call("POST", "/api/corrections", report(3, [pair("Clavio", "Klaviyo")]));
  assert.equal((await summary()).length, 1);
  db.sqlite.prepare("UPDATE correction_pairs SET received_at = ?").run(Date.now() - 181 * 86_400_000);
  assert.equal((await summary()).length, 0);
  assert.equal(db.sqlite.prepare("SELECT COUNT(*) AS n FROM correction_pairs").get().n, 0);
});
