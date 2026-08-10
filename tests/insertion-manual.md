# Insertion — manual checklist

**Never run automatically.** These need a human at the keyboard; "documented"
is not "tested". Run before each release and after touching TextInserter,
per-app rules, or the indicator. Check items off in the release PR/notes.

Setup: dev build running, mic + accessibility granted, a real dictation per
row (hold hotkey → speak a sentence → release).

## Target apps (the ones actually used)

- [ ] Notes — text lands at the cursor, correct spacing around it
- [ ] Slack message box — inserts, does NOT send (no stray Return)
- [ ] Safari — Google search field
- [ ] Chrome — a `contenteditable` editor (e.g. Gmail compose)
- [ ] An AI chat input (Claude/ChatGPT web) — inserts without submitting
- [ ] Terminal — inserts at prompt, no control characters
- [ ] A password/secure-input field — app must refuse to insert or degrade
      to clipboard, never type into the secure field

## Behaviors

- [ ] Submit-button dictation presses Return only after text landed
- [ ] No focused text field → text on clipboard + notice shown
- [ ] Per-app rule (bind a model to one app) switches model automatically
- [ ] Multi-display: indicator appears on the display with the cursor
- [ ] WiFi OFF: full dictation flow works end-to-end (the privacy promise)
- [ ] Mid-speech hotkey release: the tail of the sentence still lands

## Result log

| Date | Build | Checked by | Failures |
|---|---|---|---|
|  |  |  |  |
