const releases = [
  {
    version: "0.1.2",
    date: "August 11, 2026",
    changes: [
      "The permissions banner now opens the exact Microphone or Accessibility pane in System Settings.",
    ],
  },
  {
    version: "0.1.1",
    date: "August 11, 2026",
    changes: [
      "Double-press your shortcut to lock hands-free recording on; press again to stop.",
      "Dictation errors now explain what went wrong and how to fix it.",
      "Setup verifies your speech model before finishing and safely retries interrupted downloads.",
      "Optional local cleanup can restore short words dropped by transcription.",
    ],
  },
  {
    version: "0.1.0",
    date: "August 11, 2026",
    changes: [
      "Rhino is born: hold Fn to dictate, release to insert into any app.",
      "On-device Whisper and Parakeet transcription with optional embedded AI cleanup.",
      "Local history, writing stats, and a personal dictionary for names and jargon.",
      "No remote speech engine, no remote AI cleanup, and no telemetry.",
    ],
  },
];

export default function Changelog() {
  return (
    <main className="text-page">
      <a className="back-link" href="/">← Rhino</a>
      <h1>Changelog</h1>
      <p className="page-intro">
        What&apos;s new in Rhino—every release, in plain language. The app
        updates itself automatically.
      </p>
      {releases.map((release) => (
        <section className="release" key={release.version}>
          <div className="release-heading">
            <h2>{release.version}</h2>
            <time>{release.date}</time>
          </div>
          <ul>
            {release.changes.map((change) => <li key={change}>{change}</li>)}
          </ul>
        </section>
      ))}
    </main>
  );
}
