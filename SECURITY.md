# Security Policy

Rhino is a private pre-release project. Report security issues directly to
the maintainer (do not open a public issue if the repo ever becomes
public).

## What to report

Rhino is a macOS app that records audio, runs transcription — always
locally, there is no remote transcription — and inserts text into other
apps. Things worth reporting include, for example:

- Ways to exfiltrate audio or transcriptions — ANY code path that can move
  them off the machine is a vulnerability in this app, by definition.
- Code execution, privilege escalation, or injection via crafted input,
  models, or update feeds.
- Tampering with the Sparkle auto-update path.

## Verification in the repo

`tests/hygiene/run.sh` is the enforced privacy boundary: static scans for
remote endpoints, a networking-call-site allowlist, and live socket
monitoring during a real transcription. If you can defeat it, that is
itself a report we want.
