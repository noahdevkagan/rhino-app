/**
 * Opt-in correction sharing from the app ("Help improve accuracy",
 * OpenSuperWhisper/Utils/CorrectionReporter.swift). Off by default in the app. Installs that opt in
 * send the "Fix a word" pairs they taught Rhino (word Rhino wrote → what it should be) at most
 * weekly. No audio, no surrounding dictation, no app names, no IPs.
 *
 * The app scrubs every pair before queueing it; this file re-applies the same rules so a
 * modified client can't slip anything past them. Rows are kept 180 days. The weekly improvement
 * workflow reads only pairs taught on 3+ different Macs (`correctionsSummary`).
 * decisions.md 2026-11-02.
 */

export const MAX_WORDS = 5;
export const MAX_CHARS = 60;
export const MAX_ITEMS = 100;
export const RETENTION_DAYS = 180;
export const MIN_INSTALLS = 3;

/** Same patterns as CorrectionScrub.personalPatterns in the app. Keep the two in step. */
const personalPatterns = [
  /[^\s@]+@[^\s@]+\.[^\s@]+/, // email
  /\b(https?:\/\/|www\.)/i, // URL
  /\b[a-z0-9-]+\.(com|net|org|io|app|ai|co|dev|me|us|uk|de)\b/i, // bare domain
  /\d[\d\s.,-]{2,}\d/, // 4+ digits, even with separators
  /\d{4,}/, // 4+ digits
  /\b(sk|pk|rk|ghp|gho|xox[abp]|akia)[-_][A-Za-z0-9]/i, // well-known key prefixes
  /[A-Za-z0-9_-]{24,}/, // long token
  /\b(?=[A-Za-z0-9]*\d)(?=[A-Za-z0-9]*[A-Za-z])[A-Za-z0-9]{12,}\b/, // mixed letters+digits ≥12
];

const collapse = (text: string) => text.split(/\s+/).filter(Boolean).join(" ");

export function looksPersonal(text: string) {
  return personalPatterns.some((pattern) => pattern.test(text));
}

export function isShareable(text: string) {
  return (
    text.length > 0 &&
    [...text].length <= MAX_CHARS &&
    /\p{L}/u.test(text) &&
    text.split(" ").length <= MAX_WORDS &&
    !/[\u0000-\u001f\u007f<>]/.test(text) &&
    !looksPersonal(text)
  );
}

/** A safe pair, or null. Unsafe pairs are dropped whole. */
export function scrubPair(heard: unknown, corrected: unknown) {
  if (typeof heard !== "string" || typeof corrected !== "string") return null;
  const h = collapse(heard);
  const c = collapse(corrected);
  if (h === c || !isShareable(h) || !isShareable(c)) return null;
  return { heard: h, corrected: c };
}

const label = (value: unknown) =>
  typeof value === "string" && /^[A-Za-z0-9._-]{1,40}$/.test(value) ? value : "";
const language = (value: unknown) =>
  typeof value === "string" && /^([a-z]{2,3}(-[A-Za-z]{2,4})?|auto)$/.test(value) ? value : "";

export const installIdPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;

export type CorrectionItem = { heard: string; corrected: string; engine: string; model: string; language: string };
export type CorrectionReport = { installId: string; appVersion: string; items: CorrectionItem[] };

/**
 * Strict validation. Bad envelope → null (400). Individual pairs that fail the scrub are
 * dropped silently, so one bad pair doesn't cost the rest; an all-bad batch is still a 400.
 */
export function parseCorrectionReport(body: unknown): CorrectionReport | null {
  if (!body || typeof body !== "object") return null;
  const b = body as Record<string, unknown>;
  const installId = typeof b.installId === "string" ? b.installId.toLowerCase() : "";
  if (!installIdPattern.test(installId)) return null;
  const appVersion = typeof b.appVersion === "string" && /^[0-9A-Za-z.-]{1,20}$/.test(b.appVersion) ? b.appVersion : "";
  if (!Array.isArray(b.items) || b.items.length === 0 || b.items.length > MAX_ITEMS) return null;

  const items: CorrectionItem[] = [];
  const seen = new Set<string>();
  for (const raw of b.items) {
    if (!raw || typeof raw !== "object") return null;
    const r = raw as Record<string, unknown>;
    const pair = scrubPair(r.heard, r.corrected);
    if (!pair) continue;
    const key = `${pair.heard.toLowerCase()}\u0000${pair.corrected}`;
    if (seen.has(key)) continue;
    seen.add(key);
    items.push({ ...pair, engine: label(r.engine), model: label(r.model), language: language(r.language) });
  }
  return items.length ? { installId, appVersion, items } : null;
}

type Env = { REFERRALS?: D1Database; ADMIN_TOKEN?: string };
const env = () => (globalThis as { __rhinoEnv?: Env }).__rhinoEnv ?? {};
const db = () => {
  const binding = env().REFERRALS;
  if (!binding) throw new Error("REFERRALS D1 binding is not configured");
  return binding;
};

let schemaReady: Promise<unknown> | undefined;
function ensureSchema() {
  schemaReady ??= db()
    .batch([
      db().prepare(
        `CREATE TABLE IF NOT EXISTS correction_pairs (
           install_id TEXT NOT NULL,
           heard TEXT NOT NULL,
           heard_norm TEXT NOT NULL,
           corrected TEXT NOT NULL,
           engine TEXT NOT NULL,
           model TEXT NOT NULL,
           language TEXT NOT NULL,
           app_version TEXT NOT NULL,
           received_at INTEGER NOT NULL,
           PRIMARY KEY (install_id, heard_norm, corrected)
         )`,
      ),
      db().prepare(`CREATE INDEX IF NOT EXISTS correction_pairs_received ON correction_pairs (received_at)`),
      db().prepare(`CREATE INDEX IF NOT EXISTS correction_pairs_pair ON correction_pairs (heard_norm, corrected)`),
    ])
    .catch((error: unknown) => {
      schemaReady = undefined;
      throw error;
    });
  return schemaReady;
}

/** Deletes rows older than the retention window. Runs on every write and every summary read. */
async function purgeExpired(now = Date.now()) {
  await db()
    .prepare(`DELETE FROM correction_pairs WHERE received_at < ?`)
    .bind(now - RETENTION_DAYS * 86_400_000)
    .run();
}

export async function recordCorrections(report: CorrectionReport) {
  await ensureSchema();
  const now = Date.now();
  const statement = db().prepare(
    `INSERT INTO correction_pairs (install_id, heard, heard_norm, corrected, engine, model, language, app_version, received_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT (install_id, heard_norm, corrected) DO UPDATE SET
       heard = excluded.heard, engine = excluded.engine, model = excluded.model,
       language = excluded.language, app_version = excluded.app_version, received_at = excluded.received_at`,
  );
  await db().batch(
    report.items.map((item) =>
      statement.bind(
        report.installId, item.heard, item.heard.toLowerCase(), item.corrected,
        item.engine, item.model, item.language, report.appVersion, now,
      ),
    ),
  );
  await purgeExpired(now);
}

/** Opt-out: forget everything this install shared. */
export async function deleteCorrections(installId: string) {
  await ensureSchema();
  await db().prepare(`DELETE FROM correction_pairs WHERE install_id = ?`).bind(installId).run();
}

export type CorrectionSummaryRow = {
  heard: string;
  corrected: string;
  installs: number;
  languages: string;
  engines: string;
};

/** Pairs taught on at least MIN_INSTALLS different Macs. Nothing per-install leaves this query. */
export async function correctionsSummary(limit = 500): Promise<CorrectionSummaryRow[]> {
  await ensureSchema();
  await purgeExpired();
  const result = await db()
    .prepare(
      `SELECT MIN(heard) AS heard, corrected, COUNT(DISTINCT install_id) AS installs,
              GROUP_CONCAT(DISTINCT language) AS languages, GROUP_CONCAT(DISTINCT engine) AS engines
         FROM correction_pairs
        GROUP BY heard_norm, corrected
       HAVING COUNT(DISTINCT install_id) >= ?
        ORDER BY installs DESC, heard
        LIMIT ?`,
    )
    .bind(MIN_INSTALLS, limit)
    .all<CorrectionSummaryRow>();
  return (result.results ?? []).map((row) => ({
    heard: row.heard,
    corrected: row.corrected,
    installs: row.installs,
    languages: row.languages ?? "",
    engines: row.engines ?? "",
  }));
}

/** Constant-time bearer check against the ADMIN_TOKEN secret. No secret configured → always false. */
export function isAdmin(request: Request, token = env().ADMIN_TOKEN) {
  if (!token || token.length < 32) return false;
  const header = request.headers.get("authorization") ?? "";
  const given = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (given.length !== token.length) return false;
  let diff = 0;
  for (let i = 0; i < token.length; i++) diff |= token.charCodeAt(i) ^ given.charCodeAt(i);
  return diff === 0;
}
