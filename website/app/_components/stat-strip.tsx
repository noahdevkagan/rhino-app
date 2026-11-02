import { compactNumber, statFloors, type UsageTotals } from "../_lib/usage-stats";

/**
 * Real totals from people who opted in to anonymous usage counts. Each stat hides until it
 * clears its floor, and the whole strip hides when none do (or the database is down).
 */
export function StatStrip({ totals }: { totals: UsageTotals | null }) {
  if (!totals) return null;
  const stats = [
    totals.words >= statFloors.words && { value: compactNumber(totals.words), label: "words dictated" },
    totals.hoursSaved >= statFloors.hoursSaved && { value: compactNumber(totals.hoursSaved), label: "hours of typing saved" },
    totals.dictations >= statFloors.dictations && { value: compactNumber(totals.dictations), label: "dictations" },
    totals.activeInstalls30d >= statFloors.installs && { value: compactNumber(totals.activeInstalls30d), label: "Macs this month" },
  ].filter((s): s is { value: string; label: string } => Boolean(s));
  if (stats.length === 0) return null;
  return (
    <section className="stat-strip" aria-label="Rhino by the numbers">
      <dl>
        {stats.map((s) => (
          <div key={s.label}>
            <dt>{s.label}</dt>
            <dd>{s.value}</dd>
          </div>
        ))}
      </dl>
      <p>
        Counted only from people who turned on anonymous usage stats (off by default). Counts
        only, never your words or audio.
      </p>
    </section>
  );
}
