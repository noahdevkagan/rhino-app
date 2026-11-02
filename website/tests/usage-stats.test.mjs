import assert from "node:assert/strict";
import test from "node:test";
import { compactNumber, hoursSaved, parseUsageReport } from "../app/_lib/usage-stats.ts";

const now = new Date("2026-11-02T12:00:00Z");
const good = {
  installId: "3F2504E0-4F89-41D3-9A0C-0305E82C3301",
  appVersion: "0.1.44",
  osMajor: 15,
  days: [{ day: "2026-11-01", words: 1200, dictations: 40, secondsDictated: 600 }],
};

test("accepts a well-formed report and lowercases the install id", () => {
  const r = parseUsageReport(good, now);
  assert.equal(r.installId, "3f2504e0-4f89-41d3-9a0c-0305e82c3301");
  assert.deepEqual(r.days, good.days);
});

test("drops unknown fields so content can never be stored", () => {
  const r = parseUsageReport({ ...good, transcript: "secret", days: [{ ...good.days[0], text: "secret" }] }, now);
  assert.ok(!JSON.stringify(r).includes("secret"));
});

test("clamps absurd counts instead of trusting them", () => {
  const r = parseUsageReport({ ...good, days: [{ day: "2026-11-01", words: 1e12, dictations: -5, secondsDictated: 1e9 }] }, now);
  assert.equal(r.days[0].words, 200_000);
  assert.equal(r.days[0].dictations, 0);
  assert.equal(r.days[0].secondsDictated, 86_400);
});

test("rejects bad ids, future or ancient days, duplicates and junk", () => {
  assert.equal(parseUsageReport({ ...good, installId: "not-a-uuid" }, now), null);
  assert.equal(parseUsageReport({ ...good, days: [{ ...good.days[0], day: "2026-12-25" }] }, now), null);
  assert.equal(parseUsageReport({ ...good, days: [{ ...good.days[0], day: "2025-01-01" }] }, now), null);
  assert.equal(parseUsageReport({ ...good, days: [good.days[0], good.days[0]] }, now), null);
  assert.equal(parseUsageReport({ ...good, days: [{ ...good.days[0], words: "12" }] }, now), null);
  assert.equal(parseUsageReport({ ...good, days: [] }, now), null);
  assert.equal(parseUsageReport(null, now), null);
});

test("hours saved compares 40 wpm typing with time spent dictating", () => {
  // 2,400 words = 60 min of typing; 10 min dictating saves 50 min.
  assert.equal(hoursSaved(2400, 600), 50 / 60);
  assert.equal(hoursSaved(10, 10_000), 0);
});

test("compact numbers read cleanly", () => {
  assert.equal(compactNumber(1234), "1,234");
  assert.equal(compactNumber(340_400), "340k");
  assert.equal(compactNumber(1_200_000), "1.2M");
  assert.equal(compactNumber(2_000_000), "2M");
});
