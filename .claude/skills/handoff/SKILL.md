---
name: handoff
description: End-of-session wrap-up — rewrite HANDOFF.md (state, outstanding work, next-session prompt), append new decisions to decisions.md, and leave the tree clean. Use when the user says done, wrap up, handoff, or is ending a work session.
---

# Session handoff

Produce a clean handoff so the next session (any agent, any day) starts
with full context instead of re-deriving it. HANDOFF.md is auto-injected
into every new session by the SessionStart hook, so what you write here IS
the next session's starting context.

## Steps

1. **Rewrite `HANDOFF.md`** (replace the whole file, keep its header
   comment). Three sections, all short:
   - **Current state (dated)** — what shipped/changed this session, one
     line each. Include the released version if one was tagged.
   - **Outstanding** — unfinished work, unverified assumptions, decisions
     the maintainer still owes. Anything a next session must not forget.
   - **Next session** — the literal prompt to start from: the single most
     important next action, stated imperatively.

2. **Append to `decisions.md`** — one entry per non-obvious choice made
   this session: what was decided and the why that would otherwise be
   lost. Newest last, never rewrite old entries. Skip mechanical changes;
   log anything someone might re-litigate later.

3. **Leave the tree clean** — commit or explicitly mention anything
   uncommitted in HANDOFF.md's Outstanding section.

4. **Reply to the user** with a 3-5 line summary: what this session
   shipped, what's outstanding, and the next-session prompt.

## Rules

- HANDOFF.md is a seed, not a journal: if it grows past ~40 lines, cut —
  history lives in git log and CHANGELOG.md, reasoning in decisions.md.
- Never delete Outstanding items you didn't resolve; carry them forward.
- Commit HANDOFF.md and decisions.md changes (they're tracked files) —
  an unpushed handoff helps nobody on another machine.
