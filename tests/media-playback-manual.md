# Media playback — signed live check

These checks are manual, not automated test results. Use a signed Rhino Dev build;
unit tests never control installed players and never request TCC access.

1. With Spotify (or Music) open, turn on Settings → Dictation → Pause media during
   recording. macOS asks for Automation access right then; click Allow.
2. Open the other player afterward: it is asked for about 2s after it launches,
   once per run, and never while a recording is in progress.
3. Play a track, dictate from another app. It pauses during recording and resumes
   after the paste. Repeat with stop, cancel (Esc), and quitting Rhino.
4. Leave the player paused and dictate: it must stay paused.
5. During recording, skip the track or seek: Rhino must not resume it.
6. Deny access (or "Allow access for open apps" after a Don't Allow, which opens
   System Settings › Automation). Dictation must still work; music is untouched.
7. With the setting off, playback must remain unchanged.

Scope: Music and Spotify. Browser audio/video is not paused (dropped 2026-10-13;
the browser implementation is in git history at b8e226e/#93 if we bring it back).
