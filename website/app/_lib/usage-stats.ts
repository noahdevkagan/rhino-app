/**
 * Opt-in anonymous usage counts from the app (OpenSuperWhisper/Utils/UsageReporter.swift).
 * Off by default in the app; installs that opt in post finished days once a day. Stored
 * per (random install id, day) so a resend overwrites instead of double counting.
 * Counts only: no words, audio, app names or IPs are stored. decisions.md 2026-11-02.
 */

/** Typing speed the "hours saved" figure compares against (same as the app's Home stats). */
export const typingWpm = 40;

/** A stat stays hidden until it clears its floor: small numbers cost trust, not earn it. */
export const statFloors = { words: 100_000, hoursSaved: 100, dictations: 10_000, installs: 100 };

export type UsageDay = { day: string; words: number; dictations: number; secondsDictated: number };
export type UsageReport = { installId: string; appVersion: string; osMajor: number; days: UsageDay[] };
export type UsageTotals = {
  words: number;
  dictations: number;
  hoursSaved: number;
  activeInstalls30d: number;
};

// Per-day ceilings well above any real person: one day is 86,400 s, and 250 wpm of
// nonstop dictation for 24 h is 360k words. Anything above is clamped, not trusted.
const MAX_WORDS_PER_DAY = 200_000;
const MAX_DICTATIONS_PER_DAY = 20_000;
const MAX_SECONDS_PER_DAY = 86_400;
const MAX_DAYS = 31;

const clampInt = (value: unknown, max: number) =>
  typeof value === "number" && Number.isFinite(value) ? Math.min(max, Math.max(0, Math.floor(value))) : null;

/** Strict validation: returns a cleaned report or null. Unknown fields are dropped. */
export function parseUsageReport(body: unknown, now = new Date()): UsageReport | null {
  if (!body || typeof body !== "object") return null;
  const b = body as Record<string, unknown>;
  const installId = typeof b.installId === "string" ? b.installId.toLowerCase() : "";
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(installId)) return null;
  const appVersion = typeof b.appVersion === "string" && /^[0-9A-Za-z.\-]{1,20}$/.test(b.appVersion) ? b.appVersion : "";
  const osMajor = clampInt(b.osMajor, 99) ?? 0;
  if (!Array.isArray(b.days) || b.days.length === 0 || b.days.length > MAX_DAYS) return null;

  // Only real past days within the last ~5 weeks (UTC slack of a day for time zones).
  const latest = new Date(now.getTime() + 86_400_000).toISOString().slice(0, 10);
  const earliest = new Date(now.getTime() - 40 * 86_400_000).toISOString().slice(0, 10);
  const days: UsageDay[] = [];
  const seen = new Set<string>();
  for (const raw of b.days) {
    if (!raw || typeof raw !== "object") return null;
    const d = raw as Record<string, unknown>;
    const day = typeof d.day === "string" ? d.day : "";
    if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || Number.isNaN(Date.parse(`${day}T00:00:00Z`))) return null;
    if (day > latest || day < earliest || seen.has(day)) return null;
    seen.add(day);
    const words = clampInt(d.words, MAX_WORDS_PER_DAY);
    const dictations = clampInt(d.dictations, MAX_DICTATIONS_PER_DAY);
    const secondsDictated = clampInt(d.secondsDictated, MAX_SECONDS_PER_DAY);
    if (words === null || dictations === null || secondsDictated === null) return null;
    days.push({ day, words, dictations, secondsDictated });
  }
  return { installId, appVersion, osMajor, days };
}

/** Typing time for the same words minus the time spent dictating, in hours. */
export function hoursSaved(words: number, secondsDictated: number) {
  return Math.max(0, (words / typingWpm) * 60 - secondsDictated) / 3600;
}

// Same binding the referral counts use (worker/index.ts publishes it per request).
const db = () => {
  const binding = (globalThis as { __rhinoEnv?: { REFERRALS?: D1Database } }).__rhinoEnv?.REFERRALS;
  if (!binding) throw new Error("REFERRALS D1 binding is not configured");
  return binding;
};

let schemaReady: Promise<unknown> | undefined;
function ensureSchema() {
  schemaReady ??= db()
    .prepare(
      `CREATE TABLE IF NOT EXISTS usage_days (
         install_id TEXT NOT NULL,
         day TEXT NOT NULL,
         words INTEGER NOT NULL,
         dictations INTEGER NOT NULL,
         seconds_dictated INTEGER NOT NULL,
         app_version TEXT NOT NULL,
         os_major INTEGER NOT NULL,
         received_at INTEGER NOT NULL,
         PRIMARY KEY (install_id, day)
       )`,
    )
    .run()
    .catch((error: unknown) => {
      schemaReady = undefined;
      throw error;
    });
  return schemaReady;
}

export async function recordUsage(report: UsageReport) {
  await ensureSchema();
  const now = Date.now();
  const statement = db().prepare(
    `INSERT INTO usage_days (install_id, day, words, dictations, seconds_dictated, app_version, os_major, received_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (install_id, day) DO UPDATE SET
       words = excluded.words, dictations = excluded.dictations,
       seconds_dictated = excluded.seconds_dictated, app_version = excluded.app_version,
       os_major = excluded.os_major, received_at = excluded.received_at`,
  );
  await db().batch(
    report.days.map((d) =>
      statement.bind(report.installId, d.day, d.words, d.dictations, d.secondsDictated, report.appVersion, report.osMajor, now),
    ),
  );
}

let cached: { at: number; totals: UsageTotals } | undefined;
const CACHE_MS = 60 * 60 * 1000;

/** All-time totals plus installs seen in the last 30 days. Cached per isolate for an hour. */
export async function usageTotals(): Promise<UsageTotals> {
  if (cached && Date.now() - cached.at < CACHE_MS) return cached.totals;
  await ensureSchema();
  const since = new Date(Date.now() - 30 * 86_400_000).toISOString().slice(0, 10);
  const row = await db()
    .prepare(
      `SELECT COALESCE(SUM(words), 0) AS words, COALESCE(SUM(dictations), 0) AS dictations,
              COALESCE(SUM(seconds_dictated), 0) AS seconds,
              COUNT(DISTINCT CASE WHEN day >= ? THEN install_id END) AS installs
         FROM usage_days`,
    )
    .bind(since)
    .first<{ words: number; dictations: number; seconds: number; installs: number }>();
  const totals: UsageTotals = {
    words: row?.words ?? 0,
    dictations: row?.dictations ?? 0,
    hoursSaved: Math.round(hoursSaved(row?.words ?? 0, row?.seconds ?? 0)),
    activeInstalls30d: row?.installs ?? 0,
  };
  cached = { at: Date.now(), totals };
  return totals;
}

/** Totals for the homepage, or null when the database isn't reachable (the strip hides). */
export async function usageTotalsOrNull(): Promise<UsageTotals | null> {
  try {
    return await usageTotals();
  } catch {
    return null;
  }
}

/** Compact display: 1.2M, 340k, 1,234. */
export function compactNumber(n: number) {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(n >= 10_000_000 ? 0 : 1).replace(/\.0$/, "")}M`;
  if (n >= 10_000) return `${Math.round(n / 1000)}k`;
  return n.toLocaleString("en-US");
}
