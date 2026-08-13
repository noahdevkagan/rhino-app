# HANDOFF — session seed

Auto-injected into every Claude session in this repo (SessionStart hook in
`.claude/settings.json`). Rewritten by `/handoff` at the end of a session.
Keep it short: current state, outstanding work, and the prompt to start from.
The durable "why" behind choices goes in `decisions.md`, not here.

## Current state (2026-08-11, end of the two-day marathon)

- **Feedback email link complete (2026-08-13):** the menu-bar “Send
  Feedback…” action opens a compact Meeting Coach-style form, then hands a
  versioned, pre-addressed draft for `noahkagan@gmail.com` to the user's mail
  client. Rhino sends no telemetry or network request itself. The Debug app
  builds and the focused URL/encoding test passes.

- **Rhino v0.1.6 shipped (2026-08-12):** PR #18 merged at `4488d43` and
  immutable tag `v0.1.6` points to release commit `68b60be`. The 15.7 MB app
  and DMG passed Apple notarization and staple validation; the GitHub release,
  signed Sparkle appcast, tag-triggered CI gate, purchase download, AppSumo
  fulfillment, public changelog, and Sites deployment all publish 0.1.6.

- **First-use onboarding overlay removed (2026-08-12):** the oversized custom
  keyboard visualization and its fragile geometry are gone; the two compact
  shortcut choices remain. The app builds, all four focused onboarding tests
  pass, and a visual check at the default 900×640 window confirms the model
  picker now follows the shortcut cards without overlap.

- **Rhino v0.1.5 shipped (2026-08-12):** PR #17 merged at `9e354ba` and
  immutable tag `v0.1.5` points to release commit `13013bb`. The 15.7 MB app
  and DMG passed Apple notarization and staple validation; the GitHub release,
  signed Sparkle appcast, tag-triggered CI gate, purchase download, AppSumo
  fulfillment, public changelog, and Sites deployment all publish 0.1.5.

- **App icon refresh complete:** Rhino now uses the crisp coral-and-gray
  illustration from `Scripts/Assets/rhino-app-icon.png`; `make-icon.swift`
  generates every ICNS size inside the existing native macOS squircle. The
  Debug app builds, is validly signed, and contains the exact regenerated
  `AppIcon.icns`. The monochrome menu-bar silhouette is unchanged.

- **AppSumo listing complete:** `appsumo-listing.md` contains the validated
  copy-paste brief for one $5 AppSumo code with unlimited Apple-silicon Mac
  usage, and `appsumo-media-plan.md` covers the required icon, hero, and four
  product screenshots.

- **AppSumo submitter packet complete:** `Rhino-AppSumo-submission/` contains
  the polished Word/PDF handoff, exact listing copy, media plan, and six
  upload-ready assets. All 12 pages were rendered in Microsoft Word and
  visually verified. Do not publish until a real AppSumo code passes the
  end-to-end redemption test.

- **Rhino v0.1.4 shipped (2026-08-12):** immutable tag `v0.1.4` points to
  release commit `70fe399`; `origin/master` also includes the subsequent site
  rollout. The 15 MB Developer ID DMG and app passed Apple notarization and
  staple validation, the GitHub release and signed Sparkle appcast publish
  0.1.4, and both the full local and tag-triggered CI gates passed. The website
  download, AppSumo fulfillment, and changelog point to 0.1.4; its production
  build and seven render tests pass and the Sites deployment is live.

- **Input Monitoring false-negative fixed (2026-08-12):** Accessibility
  already authorizes the listen-only Fn event tap and is required for text
  insertion, so Rhino no longer forces a redundant Input Monitoring grant or
  trusts its stale false result over Accessibility. The monitor accepts either
  authorization for compatibility, the permission UI requests only
  Accessibility, debug builds report real TCC state, and onboarding copy
  matches. A full app build and all 16 focused trigger/authorization tests
  pass. The Developer-ID-signed patched build was launched against the user's
  existing grants and its contradictory banner is absent; installed v0.1.3
  still needs this fix in the next release.

- **AppSumo redemption is built and validated (2026-08-12):** 10,000 unique,
  high-entropy `RH-…` codes live in the gitignored
  `.context/rhino-appsumo-codes.csv`; only their SHA-256 hashes ship. The
  branded `/appsumo` page gates the v0.1.3 download, is noindexed, and handles
  loading, invalid, unavailable, and successful redemption states. The website
  production build and all seven render/generator tests pass, and the page is
  published at `https://rhinovoice.app/appsumo`.

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

### Completed benchmark check (2026-08-11)

- Retired working-name references are gone from tracked source and docs.
- Last complete personal-corpus comparison: Rhino 8/10 zero-fix (80%, 5.3%
  WER), Typeless 10/10 (100%), Wispr Flow 4/9 (44%; h03 was not captured).
- The elided-word cleanup passed a live local-Qwen A/B and fixes the known h01
  miss, so Rhino projects to 9/10; a fresh full-corpus score still needs the
  private audio/results from the original benchmark Mac.
- Fresh synthetic gate: 1.47% mean WER, zero silence hallucinations, and 410ms
  p50 / 870ms max ASR latency across four clips.
- Extended 24-clip synthetic set (509 words), with AI cleanup off: Whisper
  large-v3-turbo reached 20/24 zero-fix and 1.57% weighted WER; Parakeet v2
  reached 17/24 and 1.57%; Parakeet v3 reached 17/24 and 1.96%.

### Completed natural-voice / 8→9 experiments (2026-08-11)

- Balanced ten-clip sample from locally stored Typeless recordings (392 reference words):
  Q5 Whisper 3/10 exact agreement and 10.71% WER-to-Typeless. This is an
  agreement metric, not ground truth; the human-reviewed personal corpus remains 8/10.
- Full 1.6GB large-v3-turbo produced the same 3/10 and 10.71% WER, while steady-state
  p50 rose from 1.91s (Q5) to 2.52s. Do not make it the default on this evidence.
- Alternate decodes: beam 10.46% WER, temperature 0.2/0.4 10.20%, Parakeet 12.50%.
  Even an oracle choosing the best decoder per clip reached only 9.44% WER and
  still 3/10 exact, so confidence retry cannot supply the missing +1 alone.
- Qwen raised WER from 10.71% to 11.22%; a perfect raw-vs-Qwen guard merely restores
  10.71%. It is a safety requirement, not an accuracy gain on this sample.
- A local vocabulary/context prompt fixed `Yu` and improved WER to 10.20%, but not exact
  agreement. Universal product direction: locally learned per-user terms plus contextual
  correction; do not hard-code Noah-specific names.
- Simulating one learned correction (`Aemon`/`Amen` → `AppSumo`) increased exact agreement
  from 3/10 to 4/10. This was the only tested mechanism that converted a failed clip into
  a perfect clip, supporting correction learning as the most credible universal +1 lever.

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
