# Media playback — signed live check

These checks are manual, not automated test results. Use a signed Rhino Dev build;
unit tests never control installed players or browsers and never request TCC access.

1. Turn on Settings → Dictation → Pause media during recording. Play Music or
   Spotify, dictate, grant Automation permission on first use, and repeat.
   The first unapproved recording leaves playback alone; subsequent recordings
   pause it and resume after stop, cancellation, or quitting Rhino normally.
2. For Chrome, enable View → Developer → Allow JavaScript from Apple Events.
   For Safari, enable Settings → Advanced → Show features for web developers,
   then Allow JavaScript from Apple Events in the Developer settings (older
   Safari versions put this directly in the Develop menu). Allow Rhino's
   browser Automation request on first use.
3. Play a YouTube video in the approved browser. Dictate from another app.
   Verify pause during recording and resume of that video afterward.
4. Leave a second video paused. It must stay paused through dictation. Repeat
   with two playing tabs/windows; both should resume. Switch active tabs or move
   the playing tab to another window during recording; restore must find it.
5. During recording, change the video, seek, or manually play then pause it.
   Rhino must respect the change. Close/navigate the tab and confirm it never
   starts another video or reopens the tab/browser.
6. Disable browser JavaScript access or deny Automation. Dictation must still
   work and browser audio must remain untouched. Re-enable permission and retry.
7. Check a quick tap/release, cancel, quit during recording, and rapid successive
   recordings. No late pause or duplicate resume should occur.
8. With the setting off, music/browser playback must remain unchanged.

Scope: standard HTML audio/video in Chrome and Safari, including YouTube's own
page and same-origin frames. Cross-origin embeds, Firefox, Web Audio-only players,
closed shadow trees, and sites that reject programmatic play are unsupported.
No webpage text, URLs, or media metadata are returned to Rhino; page-local state
contains only the elements needed to restore playback. Neither the controller nor
the injected scripts issue network requests. A site may stream its own media when
playback resumes, just as it does after pressing Play.
