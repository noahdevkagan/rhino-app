# Releasing Rhino

Two release paths publish to the same place (the public
[`noahdevkagan/rhino-releases`](https://github.com/noahdevkagan/rhino-releases)
repo: GitHub release DMG + `appcast.xml` Sparkle feed). Installed apps
auto-update via Sparkle (`SUFeedURL` already points at the feed).

> Upstream OpenSuperWhisper's release docs ([`PUBLISHING.md`](./PUBLISHING.md))
> are kept for reference (toolchain gotchas, verification commands) but its
> identities/repos/two-arch scheme do not apply — Rhino ships arm64-only,
> signed as `Developer ID Application: noah kagan (U433SX7BT8)`.

## Path A — local, one command (works today)

```sh
# 1. write a "## X.Y.Z" section in CHANGELOG.md (the tag push gate enforces it)
# 2. then:
./Scripts/release.sh 0.1.1
# gate → version bump → notarized DMG → GitHub release → signed appcast
git push && SKIP_GATE=1 git push origin v0.1.1
```

Needs (all present on Noah's machine): Developer ID cert in the login
keychain, notarytool keychain profile `rhino`, Sparkle private key in the
keychain (account `Rhino`), `gh` authed with push access to rhino-releases.

The tag push also triggers `.github/workflows/release.yml`: the CI test gate
runs regardless (nothing ships untested), and the CI *publish* job skips
cleanly while its secrets are unset — no double-publish.

## Path B — CI, tag-driven (canonical once secrets are uploaded)

```sh
# 1. CHANGELOG section as above
# 2. bump the version WITHOUT publishing (release.sh does both; for the CI
#    path run its bump alone):
python3 - 0.1.1 <<'PY'
import re, sys
v = sys.argv[1]
p = 'OpenSuperWhisper.xcodeproj/project.pbxproj'
s = open(p).read()
s = re.sub(r'MARKETING_VERSION = [^;]+;', f'MARKETING_VERSION = {v};', s)
build = int(re.search(r'CURRENT_PROJECT_VERSION = (\d+);', s).group(1)) + 1
s = re.sub(r'CURRENT_PROJECT_VERSION = \d+;', f'CURRENT_PROJECT_VERSION = {build};', s)
open(p, 'w').write(s)
PY
git commit -am "Release v0.1.1"
# 3. tag + push; CI gates, builds, signs, notarizes, publishes DMG + appcast
git push && git tag v0.1.1 && SKIP_GATE=1 git push origin v0.1.1
```

CI verifies the tag matches `MARKETING_VERSION` and the CHANGELOG section
exists, then fails fast if not. Re-runs are idempotent (release upload
`--clobber`, appcast merge).

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

- **rhinovoice.app**: register the domain, put up a download page pointing at
  the latest rhino-releases DMG. The Sparkle feed does NOT depend on the
  site (it's raw.githubusercontent) — the site is marketing/download only.
- Upload the Path-B secrets when ready to move releases to CI.
