# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-11, end of the two-day marathon)

- **AppSumo redemption is built and validated (2026-08-12):** 10,000 unique,
  high-entropy `RH-…` codes live in the gitignored
  `.context/rhino-appsumo-codes.csv`; only their SHA-256 hashes ship. The
  branded `/appsumo` page gates the v0.1.3 download, is noindexed, and handles
  loading, invalid, unavailable, and successful redemption states. The website
  production build and all seven render/generator tests pass; publication is
  the remaining step in this session.

- **Rhino v0.1.3 is live (2026-08-12):** immutable tag and `origin/master`
  agreed at release commit `e5ae58a`; the 14 MB Developer ID DMG passed both
  Apple notarizations and staple validation, the GitHub release and signed
  Sparkle appcast publish 0.1.3, and the full local gate passed. The website's
  post-purchase download and changelog were advanced to 0.1.3 and its four
  production render tests pass.

- **Changelog-driven releases are one command:** after adding the newest
  numbered section, run `./Scripts/cut-release.sh`. It derives/validates the
  version, forces the full gate, bumps/commits/tags, and atomically pushes to
  `origin/master`. All eight CI secret names select the tag-driven publisher;
  otherwise it transparently uses the proven local keychain publisher. Tags
  are immutable. The non-publishing release regression suite passes.

- **Global Fn trigger fixed:** modifier-only triggers use a listen-only CGEvent
  tap, so they now request and surface macOS Input Monitoring separately from
  Accessibility. Rhino deep-links the right pane and arms the modifier tap
  once access arrives; ordinary key combos do not request the extra permission.
  The app builds and all 13 `RecordingTriggerSetTests` pass.

- **Latest `origin/master` marketing-site launch merged into the
  dictionary-crash branch:** the incoming `website/` tree is unchanged and
  the handoff conflict preserves both features. The site production build and
  4 render tests pass, as do all 35 dictionary tests.

- Fixed Home shortcut hint rendering the default Fn trigger as a dash: hints
  now read the unified `recordingTriggers` source used by ShortcutManager,
  refresh after settings changes, and have focused regression coverage. App
  build and all 11 `RecordingTriggerSetTests` pass.

### rhinovoice.app launch site

- Revised site is live at `https://rhinovoice.app`: one
  header + hero + compact footer, sharp native-size rhino emoji mark, and a
  one-time $20 PayPal checkout through `paypal@okdork.com`.
- `/thanks` delivers the v0.1.2 DMG after purchase; `/changelog` lists the three
  Rhino releases. Production render tests and live-route checks all pass.
- Cloudflare DNS, the custom hostname, and TLS are all active. The browser tab
  uses a cache-busted, full-rhino coral favicon generated at 512px through
  Next's `app/icon.png` convention; its deployed bytes match the tested asset.

- **Dictionary editor crash fixed:** deleting a rule while one of its text
  fields was focused left SwiftUI's positional `ForEach($entries)` binding
  pointing past the end of the array. Rows now bind by UUID, using their last
  rendered value for AppKit's teardown read and ignoring a late commit after
  deletion. The focused editor regression and all 35 dictionary tests pass.

- The app is **Rhino v0.1.0**: rebranded (bundle id com.noahkagan.rhino,
  coral face icon, menu-bar rhino silhouette, forced light mode), main
  window is sidebar + Home stats/History/Dictionary per Noah's mockups.
- 80/20 axe done: Rules, SenseVoice/Apple Speech, Rust autocorrect,
  translation, extra triggers, knobs — all deleted; bundle ships only
  whisper.cpp + libomp + Sparkle (DMG 28→14MB).
- Defaults ON: hold-Fn dictate, launch at login, menu-bar start, history,
  dictionary. Cleanup is an onboarding offer (explicit 1GB download).
- Shareable build: `Scripts/make-test-dmg.sh` → signed, NOTARIZED,
  stapled DMG (notarytool profile "rhino"; Sparkle keys exist, feed
  inert until rhinovoice.app + first release).
- Deterministic NumberCompaction ("forty-two thousand"→"42,000") runs on
  every transcription; unit-tested.
- **Benchmark (Noah's voice, 10 items): Rhino 80% zero-fix / 5.3% WER —
  beats Wispr Flow (44%); Typeless (100%) is the standing bar.** Grid:
  `bench/corpus/score-personal.py results/*`.
- Gate prefs leak fixed (RHINO_PREFS_SUITE); suites can no longer rewrite
  real settings.

## Outstanding

- Noah: re-record e02 + h01 (`rm audio/{e02,h01}.m4a && ./record.sh`) —
  realistic shot at 90-100% zero-fix; optionally dictate h03 into Wispr.
- Next quality lever: elided-word reconstruction in cleanup ("Schedule
  the review" — Rhino AND Wispr both dropped the "the"; Typeless's LLM
  reconstructs). Then email-tier polish.
- CI release secrets are still absent (the one-command release transparently
  uses local signing meanwhile). Upload the eight values in
  `docs/RELEASING.md` when ready to move signing/notarization into Actions.
- Localizable.xcstrings still carries orphaned keys for cut features
  (harmless); prune someday.
- CI test-gate.yml still builds with old assumptions (submodule list
  changed after autocorrect removal) — verify with a workflow_dispatch
  run before relying on it for releases.

## Next session

Start with: "Read AGENTS.md and decisions.md. If bench/corpus has fresh
recordings, rescore and update the head-to-head; then build elided-word
reconstruction into the cleanup pass and corpus-test it."
