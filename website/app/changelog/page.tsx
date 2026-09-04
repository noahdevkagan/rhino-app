const releases = [
  {
    version: "0.1.19",
    date: "September 3, 2026",
    changes: [
      "Finishing a dictation no longer starts music you had paused. Rhino now checks whether media was actually playing (Spotify and Music tell it directly) instead of guessing from whether anything was using the speakers — so a paused song, a Zoom call, or Rhino's own start chime no longer trigger a resume.",
      "No more phantom “Thank you.” typed when you said nothing. Whisper's stock silence hallucinations are filtered only when the audio agrees there was no speech — a real “Thank you.” you dictate still comes through.",
      "Hands-free start chime no longer stutters when you double- or triple-tap the dictate key.",
      "Failed dictations in History now show the exact error, in selectable text you can paste into a support report.",
      "New envelope button in the sidebar footer opens Send Feedback in one click.",
      "The version number in the sidebar is now clickable and opens What's New. Also fixed: Home's “Get a model” banner sometimes opened Settings on the wrong tab.",
    ],
  },
  {
    version: "0.1.18",
    date: "August 31, 2026",
    changes: [
      "Dictation lands noticeably faster. AI cleanup no longer re-reads its full instructions on every dictation — they're prepared once and warmed up while you're still speaking — roughly halving cleanup time per dictation, and cutting it ~6× with smart formatting on. The speech model also runs a warm-up at launch, so the first dictation of the day is as fast as the tenth.",
      "Custom dictionary's “boost recognition” no longer rebuilds its vocabulary on every dictation — boosted dictations are up to ~3× faster.",
      "Slow-dictation reports can now pinpoint the cause: every dictation logs where its time went (reading audio, transcription, cleanup).",
    ],
  },
  {
    version: "0.1.17",
    date: "August 31, 2026",
    changes: [
      "New: hide the menu bar icon (Settings → Advanced → App). Dictation keeps working with it hidden; open Rhino again from Applications or Spotlight to bring the window back.",
      "Picking Fn as your dictate key in Settings now also switches off the Mac's own press-🌐-for-emoji shortcut, so the emoji picker stops popping up in the middle of dictating. Setup already did this — switching to Fn afterwards didn't. Emoji stays available on ⌃⌘Space, and you can undo it in System Settings → Keyboard.",
    ],
  },
  {
    version: "0.1.16",
    date: "August 27, 2026",
    changes: [
      "Setup now recommends Parakeet v2 — the fastest, most accurate pick for English and the model behind our published accuracy benchmark. Dictating in another language? Pick Whisper Large v3 Turbo in setup, or Parakeet v3 (multilingual) any time in Settings → Models.",
    ],
  },
  {
    version: "0.1.15",
    date: "August 27, 2026",
    changes: [
      "New: Spoken edits. Correct yourself out loud — “the demo is Tuesday… wait, scrap that, it moved to Thursday” — and Rhino types only the corrected version. Works with “scrap that”, “I mean”, “actually, make that…”, and “scrap all of that” to start over. Off by default in Settings → Output → Cleanup.",
      "Dictated emails now format properly at real length: longer messages come out in short paragraphs instead of one solid block, and the sign-off name no longer picks up a stray period.",
      "Music and podcasts resume again after dictating when “pause audio while dictating” is on.",
      "Dictating in German (or any non-English language) no longer comes back in English or Russian at times: cleanup is pinned to your dictation language, and Parakeet is told which language you selected instead of guessing per phrase.",
      "Fixed a rare crash — and a stuck live microphone — when the dictate key was released almost immediately after pressing it.",
    ],
  },
  {
    version: "0.1.14",
    date: "August 20, 2026",
    changes: [
      "Setup is now three numbered steps shown one at a time — Permissions → Dictate key → Speech model — moving forward automatically as you complete each, instead of one long screen that read like settings.",
      "When an update is available, the red dot now sits on the rhino icon in the menu bar like a notification badge, instead of floating as a stray dot beside it.",
      "A new “Dictionary…” item in the menu bar (⌘D while the menu is open) opens the main window already on the Dictionary tab, so you can add or fix a word immediately.",
    ],
  },
  {
    version: "0.1.13",
    date: "August 20, 2026",
    changes: [
      "Smart formatting now lays dictated emails out as emails — greeting on its own line, a blank line between thoughts, sign-off and name on their own lines — instead of one long run-on line.",
      "Say “new line” or “new paragraph” while dictating (with smart formatting on) to insert real breaks. Sentences that just happen to contain those words are left alone.",
      "Memory no longer climbs dictation after dictation with Parakeet: the speech model is loaded once and reused, instead of being rebuilt for every dictation and live preview.",
    ],
  },
  {
    version: "0.1.12",
    date: "August 19, 2026",
    changes: [
      "First-time setup walks you through the two permissions Rhino needs, with live status — and registers Rhino in the Accessibility list for you.",
      "Setup is simpler: pick one of two speech models (Parakeet v3 recommended), with punctuation cleanup as a clearly optional add-on.",
      "The dictate-key choice in setup now actually applies, and the alternative key is Right \u2318.",
      "After setup, pressing Fn no longer pops the Mac's emoji picker mid-dictation. Emoji stays available with \u2303\u2318Space.",
      "Parakeet downloads show a real progress bar, plus a note while the model is optimized for your Mac.",
      "Fixed a crash that could hit the next dictation after AirPods or your microphone changed, and a rare crash when cancelling with Esc just as a transcription finished.",
      "Dictations no longer vanish silently when the Accessibility grant has gone stale: the text stays on the clipboard with a notice explaining the one-time fix.",
    ],
  },
  {
    version: "0.1.11",
    date: "August 19, 2026",
    changes: [
      "First-time setup no longer fails with a \"TranscriptionError error 0\" dialog when Parakeet was already downloaded: the checkmarked model is now the one Continue actually verifies.",
      "The menu bar shows a red dot and an \"Install Update…\" item when an update is ready to install; both clear once you're up to date.",
      "Speech-model load failures now explain what went wrong in plain words instead of a raw error code.",
    ],
  },
  {
    version: "0.1.10",
    date: "August 18, 2026",
    changes: [
      "Home and History are now one screen: your dictation stats sit on top with your history and search right below.",
      "The active model is shown on Home so you can always see what's doing the transcribing — click it to switch models.",
      "Settings opens inside the main window and was redesigned with Apple-style grouped cells.",
      "The recording indicator is now a compact black pill docked at the bottom of the screen, showing the app you're dictating into and a live waveform.",
      "The live transcription preview shows your words sooner and the bubble expands smoothly instead of snapping.",
      "About Rhino: thank you to Paul Stamatiou for all the feedback.",
    ],
  },
  {
    version: "0.1.9",
    date: "August 18, 2026",
    changes: [
      "Same app as 0.1.8, re-issued with a new update-signing key after moving releases to a new machine. If your installed Rhino can't verify the update, download this version once and future updates work normally again.",
    ],
  },
  {
    version: "0.1.8",
    date: "August 18, 2026",
    changes: [
      "Turning on \"Clean up with an LLM\" now downloads the on-device cleanup model automatically, so cleanup and Smart formatting work right away.",
      "Update prompts now include the matching changelog notes, so you can see what's new before installing each update.",
    ],
  },
  {
    version: "0.1.7",
    date: "August 13, 2026",
    changes: [
      "Optional Smart formatting turns dictated enumerations into bulleted or numbered lists entirely on-device.",
      "Finished dictations now appear sooner by removing redundant audio work and moving history bookkeeping after text insertion.",
      "The menu-bar feedback form opens a prefilled email to Noah with the running Rhino version.",
    ],
  },
  {
    version: "0.1.6",
    date: "August 12, 2026",
    changes: [
      "First-time setup no longer shows an oversized keyboard diagram over the shortcut and speech-model choices.",
    ],
  },
  {
    version: "0.1.5",
    date: "August 12, 2026",
    changes: [
      "Rhino's app icon now uses crisp high-resolution artwork that stays sharp at every macOS icon size.",
    ],
  },
  {
    version: "0.1.4",
    date: "August 12, 2026",
    changes: [
      "The Fn shortcut no longer gets stuck in an Input Monitoring permission loop; Rhino now uses its existing Accessibility permission for global Fn detection and text insertion.",
    ],
  },
  {
    version: "0.1.3",
    date: "August 12, 2026",
    changes: [
      "The Fn shortcut now works while other apps are focused and clearly requests Input Monitoring access when needed.",
      "Deleting a dictionary rule no longer crashes when one of its text fields is focused.",
      "The Home screen now shows the active dictation shortcut instead of a dash.",
    ],
  },
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
