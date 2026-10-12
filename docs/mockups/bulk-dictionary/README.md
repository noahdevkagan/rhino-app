# Bulk dictionary — design proposal

Status: shipped. This is the mockup the flow was reviewed from; the app now has
the native paste/review sheet (`DictionaryBulkImport.swift`,
`DictionaryBulkImportView.swift`). Kept for the design history.

![Review words and optional exact corrections](preview.png)

Download [index.html](index.html) using GitHub's download button and open it
in a browser, or open it from a local checkout. It works offline and does not
read or change your Rhino dictionary. Click **Back to paste** to try the full
flow. The editable conversation fragment is [source.html](source.html).

## Proposed flow

1. Paste one word per line, or copy two spreadsheet columns: **Correct
   spelling**, then **Rhino hears it as** (optional). No header row is needed.
2. Review the entries and fill in any known mishearings.
3. Add the entries together.

A word by itself tells Rhino the desired spelling. Existing sound-alike
matching tries close misses for eligible single words with at least five
letters; it does not train the speech model or guarantee a correction. It
avoids changing recognized English words and requires sound-alike matching
to be enabled in Settings → Output.

An explicit pair such as `Joe → Jo` tells Rhino exactly what to replace.
Short words and phrases need this second value, and the review screen asks for
it before saving those entries.

## Scope

The prototype demonstrates newline/tab-separated paste, blank-line handling,
identical-row deduplication, editable corrections, validation, and a simulated
save. CSV files and headers remain out of scope. The shipped version goes
further than the mockup: it opens from the shared Dictionary/Settings editor,
merges into existing rules without losing IDs, spacing or alternates, and
rejects a mishearing that already points at a different spelling.

The standalone export retains the mockup's own styles and logic, omits the
visualization renderer's unused remote libraries and host bridge, and blocks
network requests through its content security policy.

## Validation

Checked in Chrome: initial review state, one- and two-column paste, required
mishearing for a short name, empty-input rejection, and simulated save. The
360px layout has no horizontal overflow. Desktop screenshot reviewed; no
JavaScript runtime errors or HTTP requests observed. The native flow is covered
by `OpenSuperWhisperTests/DictionaryBulkImportTests.swift`.
