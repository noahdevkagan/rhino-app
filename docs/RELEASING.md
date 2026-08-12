# Releasing Rhino

Two release paths publish to the same place (the public
[`noahdevkagan/rhino-releases`](https://github.com/noahdevkagan/rhino-releases)
repo: GitHub release DMG + `appcast.xml` Sparkle feed). Installed apps
auto-update via Sparkle (`SUFeedURL` already points at the feed).

> Upstream OpenSuperWhisper's release docs ([`PUBLISHING.md`](./PUBLISHING.md))
> are kept for reference (toolchain gotchas, verification commands) but its
> identities/repos/two-arch scheme do not apply — Rhino ships arm64-only,
> signed as `Developer ID Application: noah kagan (U433SX7BT8)`.

## Cut a release — one command

```sh
# 1. Put the next version at the top of CHANGELOG.md, with release-note bullets:
#    ## 0.1.3 — 2026-08-11
# 2. Run from a checkout at origin/master (a pending CHANGELOG-only edit or
#    commit is allowed):
./Scripts/cut-release.sh
```

`cut-release.sh` reads the first numbered changelog heading, requires it to be
newer than every existing tag, runs the full gate, bumps the marketing/build
versions, creates `Release vX.Y.Z`, creates the immutable tag, and atomically
pushes the commit + tag to `origin/master`. It refuses unmerged code and dirty
files other than `CHANGELOG.md`, so a release cannot accidentally scoop up an
agent's working tree.

The command checks the *names* of the repo's Actions secrets. When all eight
CI signing/publishing secrets exist, the tag-triggered workflow builds,
notarizes, publishes the DMG, and updates Sparkle. Until then, the same command
automatically uses the proven local publisher before pushing; the tag workflow
still re-runs the CI gate and skips its publish job, so it cannot double-publish.

The local fallback needs (all present on Noah's machine): Developer ID cert in
the login keychain, notarytool keychain profile `rhino`, Sparkle private key in
the keychain (account `Rhino`), and `gh` authenticated with push access to
`rhino-app` and `rhino-releases`.

## Manual/repair path

Normally use `cut-release.sh`. For a deliberate local-only publish or repair,
the lower-level command remains:

```sh
./Scripts/release.sh 0.1.3
git push
SKIP_GATE=1 git push origin v0.1.3
```

Release tags cannot be reused or moved. If publication failed after the tag was
pushed, fix the publisher and re-run the existing GitHub Actions job instead of
force-tagging. CI verifies that the tag matches `MARKETING_VERSION` and the
changelog section before it publishes.

### One-time secret setup (rhino-app repo → Settings → Secrets → Actions)

| Secret | Value | How to get it |
|---|---|---|
| `MACOS_CERT_P12_BASE64` | Developer ID Application cert + key, base64 | Keychain Access → export cert as `.p12` with a password → `base64 -i cert.p12 \| pbcopy` |
| `MACOS_CERT_PASSWORD` | that `.p12`'s password | you chose it at export |
| `MACOS_DEVELOPER_ID_APP` | `Developer ID Application: noah kagan (U433SX7BT8)` | `security find-identity -v -p codesigning` |
| `MACOS_TEAM_ID` | `U433SX7BT8` | same |
| `MACOS_NOTARY_APPLE_ID` | the Apple ID email used for notarization | — |
| `MACOS_NOTARY_PASSWORD` | an **app-specific password** for that Apple ID | appleid.apple.com → App-Specific Passwords |
| `SPARKLE_ED_PRIVATE_KEY` | Sparkle EdDSA private key (one base64 line) | `SourcePackages/artifacts/*/Sparkle/bin/generate_keys -x /tmp/k --account Rhino && cat /tmp/k \| pbcopy && rm -P /tmp/k` |
| `RELEASES_TOKEN` | fine-grained PAT, **Contents: read/write** on `noahdevkagan/rhino-releases` | github.com → Settings → Developer settings → Fine-grained tokens |

## Verify a shipped DMG

```sh
xcrun stapler validate Rhino-<ver>.dmg
hdiutil attach Rhino-<ver>.dmg
spctl -a -vvv -t exec /Volumes/Rhino/Rhino.app   # → accepted, Notarized Developer ID
```

## Still TODO (needs Noah)

- Upload the eight Actions secrets above when ready to move releases from the
  local fallback into CI.
- The live site's `/thanks` download URL and `/changelog` data are still pinned
  in `website/`; update and deploy those for each public release. Sparkle does
  not depend on the site because its feed is served from `rhino-releases`.
