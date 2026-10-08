import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Rhino Voice Changelog: Every Release in Plain English",
  description:
    "What changed in each Rhino Voice release for Mac, newest first: faster dictation, dictionary fixes, new settings and bug fixes.",
  alternates: { canonical: "https://rhinovoice.app/changelog" },
};

const releases = [
  {
    version: "0.1.37",
    date: "October 8, 2026",
    changes: [
      "The dictation bubble stays near the mouse when an app reports an invalid text cursor location, instead of appearing at a screen corner.",
    ],
  },
  {
    version: "0.1.36",
    date: "October 6, 2026",
    changes: [
      "The dictation bubble opens at its final size instead of flashing a wide empty bar. Cursor placement settles before it appears, so a slow caret lookup no longer makes it jump across the screen.",
      "Saying \"period\" at the end of a sentence now ends it, even without a pause: \"I had salmon for dinner period\" types \"I had salmon for dinner.\" instead of \"dinner, period.\" Phrases like \"billing period\" or \"the Jurassic period\" keep the word.",
    ],
  },
  {
    version: "0.1.35",
    date: "October 6, 2026",
    changes: [
      "Get Rhino Unlimited free by inviting 2 friends. Click Get Unlimited free in the sidebar or Get Rhino Unlimited for free in the menu bar (also offered when your free words run out), and send your personal link. When 2 friends get Rhino through it, your invite page gives you a one-click unlock. Friends can get Rhino free on AppSumo or download the free version.",
      "The share popup no longer appears on its own after a few dictations.",
    ],
  },
  {
    version: "0.1.34",
    date: "October 5, 2026",
    changes: [
      "Faster dictation with cleanup on: ordinary sentences are now inserted as soon as they're recognized. The cleanup model runs only when there is something to format, like an email or message, a list, or \"new line\" / \"new paragraph\". Turn this off under Settings → Output → Cleanup to clean up every dictation (English; other languages are unchanged).",
      "Cleanup can no longer silently delete a sentence or replace your words with a drafted reply: when its output drops or invents too much, Rhino keeps the transcript as spoken.",
      "\"Thanks a million\" and \"Million Dollar Weekend\" stay as words instead of becoming 1,000,000.",
      "Parakeet no longer uses dictionary \"Boost recognition\", which could drop whole sentences. The dictionary still fixes your names and terms. The toggle remains for Whisper.",
      "Dictations into Conductor are inserted as spoken, like Claude and ChatGPT.",
      "Fix missed spoken \"period\" commands after common sentence endings, such as \"see you there period\" and \"thanks for reporting this period\", with Smart formatting on. Spaced or repeated punctuation around a command is consumed once, preventing extra full stops. Literal phrases such as \"billing period\" stay intact.",
      "Drop MP4 videos into Rhino to transcribe their audio entirely on-device. History keeps the extracted audio, without storing a copy of the video.",
      "Fixed a launch crash loop after an audio import was interrupted. Interrupted recordings now show a failure with a manual retry option in History.",
      "Hardened Parakeet audio imports so unreadable files report an error instead of using the conversion path implicated in M4A crashes.",
      "The Rhino Unlimited window is easier to read: the Get Unlimited button is always highlighted, even while you're working in another app, and the window is more compact.",
    ],
  },
  {
    version: "0.1.33",
    date: "October 5, 2026",
    changes: [
      "One-click unlock. After buying Rhino or redeeming an AppSumo code, click Unlock Rhino on the website and Rhino opens already unlimited. No code to copy or type.",
    ],
  },
  {
    version: "0.1.32",
    date: "October 4, 2026",
    changes: [
      "Rhino is now free to download. New installs get unlimited dictation for their first week, then 2,000 words a week free, every week. Unlimited is $20 once: choose Get Rhino Unlimited in the menu bar and enter the code from your purchase or your AppSumo code.",
      "Already using Rhino? Nothing changes for you. Every install set up before this version stays unlimited automatically.",
    ],
  },
  {
    version: "0.1.31",
    date: "October 2, 2026",
    changes: [
      "Dictate punctuation the way you do on your phone. With Smart formatting on, saying \"period\", \"comma\", \"question mark\", \"exclamation point\", \"colon\", \"new line\" or \"new paragraph\" (with a short pause around it) types the mark or the break instead of the word. Sentences that just mention the words, like \"a grace period\" or \"the word comma\", are left alone.",
      "English numbers format automatically: \"zero point seven two five\" becomes \"0.725\" and \"seven items\" becomes \"7 items.\" Choose Smart, Prefer digits, or Keep as spoken in Settings, Output, Numbers. Everyday phrases stay words: \"at that point two people left\", \"one day\", \"one more thing\", \"the one\".",
    ],
  },
  {
    version: "0.1.30",
    date: "September 25, 2026",
    changes: [
      "Teaching Rhino a word is easier. Rule editing now opens right inside the Dictionary card instead of a popup that could get cut off, asks for the correct spelling first, and makes the \"Rhino hears it as\" spelling optional. Empty rules are cleaned up automatically.",
      "New \"Fix sound-alikes\" setting (on by default): a word you add also fixes near-miss spellings of it. Add \"Klaviyo\" and \"Clavio\" or \"Claviyo\" get fixed too, without listing them. Real words are never changed, so \"Stripe\" won't touch \"strip\".",
      "Your dictionary now runs again after AI cleanup, so cleanup can no longer undo a spelling you fixed.",
      "\"Fix a word\" in History: pick a misheard word in a past transcript and teach Rhino the right spelling on the spot.",
    ],
  },
  {
    version: "0.1.29",
    date: "September 25, 2026",
    changes: [
      "With \"Pause media during recording\" on, Rhino no longer starts music or videos you had paused yourself. It used to guess what was playing from background audio activity, which could restart a paused browser tab or Music after you finished dictating. Rhino now resumes playback only when it actually paused Music or Spotify for that recording.",
      "Browser media (YouTube and similar) still pauses while you dictate, but no longer resumes on its own afterward. Press play when you're ready.",
    ],
  },
  {
    version: "0.1.28",
    date: "September 24, 2026",
    changes: [
      "Rhino finishes faster after you stop talking. The AI cleanup pass used to re-type your transcript one word-piece at a time; it now guesses ahead from what you said and checks many pieces at once, keeping only what it would have written anyway. In a local benchmark a 77-word dictation dropped from 1.3 seconds to 0.44 and a 249-word one from 4.3 seconds to 0.74. The first dictation after Rhino has been idle is quicker too. The wording of your transcripts is unchanged.",
      "With \"Pause media during recording\" on, Rhino no longer starts music you had paused yourself. Some apps keep a silent audio stream open in the background, which Rhino mistook for playing media and then \"resumed\" after dictating. Rhino now only resumes known media apps like browsers and music, podcast and video players.",
    ],
  },
  {
    version: "0.1.27",
    date: "September 23, 2026",
    changes: [
      "Happy Rhino Day! Give three friends Rhino Voice for free through AppSumo with coupon rhinofree. Open “Give 3 friends Rhino for free…” in the menu bar to copy the link and coupon or a ready-to-send invitation.",
      "A one-time sharing popup appears after five successful dictations, once Rhino is idle. It leaves your typing focus alone and disappears when you start another recording.",
    ],
  },
  {
    version: "0.1.26",
    date: "September 22, 2026",
    changes: [
      "If you run a clipboard manager like Maccy, your dictations no longer pile up in its history. With \"Copy to clipboard\" off, Rhino only borrows the clipboard for about a second to paste, and fast clipboard managers could grab the text in that window. The borrowed text is now marked as temporary, the standard signal clipboard managers use to skip an entry. Anything you copy yourself still shows up in history as before.",
    ],
  },
  {
    version: "0.1.25",
    date: "September 22, 2026",
    changes: [
      "Dictation comes back faster when you use spoken corrections and smart formatting together. Rhino runs those as two AI passes, and each one used to evict the other's warmed-up instructions, so every dictation re-read several hundred tokens of setup after you stopped speaking. Both passes now stay warm at once: in a local benchmark that path dropped from about 2.2 seconds to 0.5. The wording of your transcripts is unchanged.",
    ],
  },
  {
    version: "0.1.24",
    date: "September 17, 2026",
    changes: [
      "Starting a recording no longer waits on the app you're dictating into. Whatever you've bound (Fn, a custom shortcut, hold-to-record or the double-tap hands-free start) begins right away, even when that app is slow to answer. Rhino used to ask the app where your text cursor was before it began, so an app with a busy Accessibility server could hold up the start of a recording. Those lookups now happen in the background: the recording bubble appears immediately at your pointer and moves to the text cursor once the app replies. The bubble's entrance is also quicker and less bouncy.",
    ],
  },
  {
    version: "0.1.23",
    date: "September 16, 2026",
    changes: [
      "Long dictations no longer come back cut off mid-sentence. Rhino's AI cleanup pass could truncate transcripts past roughly four minutes of speech; it now skips cleanup on very long recordings and throws away any cleaned-up text that came back incomplete, so you always keep the full transcript.",
      "Dictating in another language with Language set to Auto-detect no longer turns your words into English. Rhino now identifies the language on your Mac before the cleanup pass and holds it there, and discards the cleanup result outright if it switches languages anyway.",
    ],
  },
  {
    version: "0.1.22",
    date: "September 13, 2026",
    changes: [
      "The recording bubble can no longer get stuck on screen. If a transcription never finishes, the bubble dismisses itself after two minutes, and pressing Esc now closes it in every state instead of only while recording, so you no longer have to quit Rhino to get rid of it.",
      "Dictating into Claude, ChatGPT, or a terminal (Terminal, iTerm2, Warp, WezTerm, kitty, Ghostty, Hyper) now inserts your words verbatim. Rhino skips its AI cleanup pass for those apps so instructions meant for the assistant are passed through instead of being acted on. Toggle under Settings → Advanced → Safeguards.",
      "Recordings of five minutes or longer are copied to your clipboard and flagged with a \"copied, press ⌘V to paste\" note instead of being pasted automatically, so a forgotten recording can't dump a wall of text into whatever you had open. History still saves the transcript. Toggle under Settings → Advanced → Safeguards.",
    ],
  },
  {
    version: "0.1.21",
    date: "September 5, 2026",
    changes: [
      "Dictating with AirPods no longer gets stuck on \"Connecting…\". Rhino now opens a fresh audio connection for every dictation, so AirPods that reconnected since your last one are picked up correctly instead of freezing the app until you quit it.",
      "If AirPods (or any headset mic) disconnect between dictations, Rhino falls back to your Mac's microphone within a few seconds instead of waiting forever.",
      "If the live preview can't start, the dictation still records and transcribes normally; only the on-screen preview is skipped.",
    ],
  },
  {
    version: "0.1.20",
    date: "September 4, 2026",
    changes: [
      "Dictation no longer pastes twice when two copies of Rhino are running. Launching Rhino now takes over from any older copy still open, the stuck instance left behind by an update, or a second copy started from Downloads or a mounted disk image, instead of both of them typing your words.",
      "Onboarding no longer asks you to download a speech model you already have: if Parakeet v3 is on your Mac, it's offered as a choice and Finish works right away.",
      "The main window can be resized freely again; dragging its edge no longer snaps it back to a narrow width that clipped the layout.",
    ],
  },
  {
    version: "0.1.19",
    date: "September 3, 2026",
    changes: [
      "Finishing a dictation no longer starts music you had paused. Rhino now checks whether media was actually playing (Spotify and Music tell it directly) instead of guessing from whether anything was using the speakers, so a paused song, a Zoom call, or Rhino's own start chime no longer trigger a resume.",
      "No more phantom “Thank you.” typed when you said nothing. Whisper's stock silence hallucinations are filtered only when the audio agrees there was no speech. A real “Thank you.” you dictate still comes through.",
      "Hands-free start chime no longer stutters when you double- or triple-tap the dictate key.",
      "Failed dictations in History now show the exact error, in selectable text you can paste into a support report.",
      "New envelope button in the sidebar footer opens Send Feedback in one click.",
      "The version number in the sidebar is now clickable and opens What's New. Also fixed: Home's “Get a model” banner sometimes opened Settings on the wrong tab.",
    ],
  },
  {
    version: "0.1.18",
    date: "August 31, 2026",
    changes: [
      "Dictation lands noticeably faster. AI cleanup no longer re-reads its full instructions on every dictation. They're prepared once and warmed up while you're still speaking, roughly halving cleanup time per dictation, and cutting it ~6× with smart formatting on. The speech model also runs a warm-up at launch, so the first dictation of the day is as fast as the tenth.",
      "Custom dictionary's “boost recognition” no longer rebuilds its vocabulary on every dictation, so boosted dictations are up to ~3× faster.",
      "Slow-dictation reports can now pinpoint the cause: every dictation logs where its time went (reading audio, transcription, cleanup).",
    ],
  },
  {
    version: "0.1.17",
    date: "August 31, 2026",
    changes: [
      "New: hide the menu bar icon (Settings → Advanced → App). Dictation keeps working with it hidden; open Rhino again from Applications or Spotlight to bring the window back.",
      "Picking Fn as your dictate key in Settings now also switches off the Mac's own press-🌐-for-emoji shortcut, so the emoji picker stops popping up in the middle of dictating. Setup already did this; switching to Fn afterwards didn't. Emoji stays available on ⌃⌘Space, and you can undo it in System Settings → Keyboard.",
    ],
  },
  {
    version: "0.1.16",
    date: "August 27, 2026",
    changes: [
      "Setup now recommends Parakeet v2, the fastest, most accurate pick for English and the model behind our published accuracy benchmark. Dictating in another language? Pick Whisper Large v3 Turbo in setup, or Parakeet v3 (multilingual) any time in Settings → Models.",
    ],
  },
  {
    version: "0.1.15",
    date: "August 27, 2026",
    changes: [
      "New: Spoken edits. Correct yourself out loud (“the demo is Tuesday… wait, scrap that, it moved to Thursday”) and Rhino types only the corrected version. Works with “scrap that”, “I mean”, “actually, make that…”, and “scrap all of that” to start over. Off by default in Settings → Output → Cleanup.",
      "Dictated emails now format properly at real length: longer messages come out in short paragraphs instead of one solid block, and the sign-off name no longer picks up a stray period.",
      "Music and podcasts resume again after dictating when “pause audio while dictating” is on.",
      "Dictating in German (or any non-English language) no longer comes back in English or Russian at times: cleanup is pinned to your dictation language, and Parakeet is told which language you selected instead of guessing per phrase.",
      "Fixed a rare crash (and a stuck live microphone) when the dictate key was released almost immediately after pressing it.",
    ],
  },
  {
    version: "0.1.14",
    date: "August 20, 2026",
    changes: [
      "Setup is now three numbered steps shown one at a time (Permissions → Dictate key → Speech model), moving forward automatically as you complete each, instead of one long screen that read like settings.",
      "When an update is available, the red dot now sits on the rhino icon in the menu bar like a notification badge, instead of floating as a stray dot beside it.",
      "A new “Dictionary…” item in the menu bar (⌘D while the menu is open) opens the main window already on the Dictionary tab, so you can add or fix a word immediately.",
    ],
  },
  {
    version: "0.1.13",
    date: "August 20, 2026",
    changes: [
      "Smart formatting now lays dictated emails out as emails: greeting on its own line, a blank line between thoughts, sign-off and name on their own lines, instead of one long run-on line.",
      "Say “new line” or “new paragraph” while dictating (with smart formatting on) to insert real breaks. Sentences that just happen to contain those words are left alone.",
      "Memory no longer climbs dictation after dictation with Parakeet: the speech model is loaded once and reused, instead of being rebuilt for every dictation and live preview.",
    ],
  },
  {
    version: "0.1.12",
    date: "August 19, 2026",
    changes: [
      "First-time setup walks you through the two permissions Rhino needs, with live status, and registers Rhino in the Accessibility list for you.",
      "Setup is simpler: pick one of two speech models (Parakeet v3 recommended), with punctuation cleanup as a clearly optional add-on.",
      "The dictate-key choice in setup now actually applies, and the alternative key is Right \u2318.",
      "After setup, pressing Fn no longer pops the Mac's emoji picker mid-dictation. Emoji stays available with \u2303\u2318Space.",
      "Parakeet downloads show a real progress bar, plus a note while the model is optimized for your Mac.",
      "Fixed a crash that could hit the next dictation after AirPods or your microphone changed, and a rare crash when cancelling with Esc just as a transcription finished.",
      "Dictations no longer vanish silently when the Accessibility grant has gone stale: the text stays on the clipboard with a notice explaining the one-time fix.",
    ],
  },
  {
    version: "0.1.11",
    date: "August 19, 2026",
    changes: [
      "First-time setup no longer fails with a \"TranscriptionError error 0\" dialog when Parakeet was already downloaded: the checkmarked model is now the one Continue actually verifies.",
      "The menu bar shows a red dot and an \"Install Update…\" item when an update is ready to install; both clear once you're up to date.",
      "Speech-model load failures now explain what went wrong in plain words instead of a raw error code.",
    ],
  },
  {
    version: "0.1.10",
    date: "August 18, 2026",
    changes: [
      "Home and History are now one screen: your dictation stats sit on top with your history and search right below.",
      "The active model is shown on Home so you can always see what's doing the transcribing. Click it to switch models.",
      "Settings opens inside the main window and was redesigned with Apple-style grouped cells.",
      "The recording indicator is now a compact black pill docked at the bottom of the screen, showing the app you're dictating into and a live waveform.",
      "The live transcription preview shows your words sooner and the bubble expands smoothly instead of snapping.",
      "About Rhino: thank you to Paul Stamatiou for all the feedback.",
    ],
  },
  {
    version: "0.1.9",
    date: "August 18, 2026",
    changes: [
      "Same app as 0.1.8, re-issued with a new update-signing key after moving releases to a new machine. If your installed Rhino can't verify the update, download this version once and future updates work normally again.",
    ],
  },
  {
    version: "0.1.8",
    date: "August 18, 2026",
    changes: [
      "Turning on \"Clean up with an LLM\" now downloads the on-device cleanup model automatically, so cleanup and Smart formatting work right away.",
      "Update prompts now include the matching changelog notes, so you can see what's new before installing each update.",
    ],
  },
  {
    version: "0.1.7",
    date: "August 13, 2026",
    changes: [
      "Optional Smart formatting turns dictated enumerations into bulleted or numbered lists entirely on-device.",
      "Finished dictations now appear sooner by removing redundant audio work and moving history bookkeeping after text insertion.",
      "The menu-bar feedback form opens a prefilled email to Noah with the running Rhino version.",
    ],
  },
  {
    version: "0.1.6",
    date: "August 12, 2026",
    changes: [
      "First-time setup no longer shows an oversized keyboard diagram over the shortcut and speech-model choices.",
    ],
  },
  {
    version: "0.1.5",
    date: "August 12, 2026",
    changes: [
      "Rhino's app icon now uses crisp high-resolution artwork that stays sharp at every macOS icon size.",
    ],
  },
  {
    version: "0.1.4",
    date: "August 12, 2026",
    changes: [
      "The Fn shortcut no longer gets stuck in an Input Monitoring permission loop; Rhino now uses its existing Accessibility permission for global Fn detection and text insertion.",
    ],
  },
  {
    version: "0.1.3",
    date: "August 12, 2026",
    changes: [
      "The Fn shortcut now works while other apps are focused and clearly requests Input Monitoring access when needed.",
      "Deleting a dictionary rule no longer crashes when one of its text fields is focused.",
      "The Home screen now shows the active dictation shortcut instead of a dash.",
    ],
  },
  {
    version: "0.1.2",
    date: "August 11, 2026",
    changes: [
      "The permissions banner now opens the exact Microphone or Accessibility pane in System Settings.",
    ],
  },
  {
    version: "0.1.1",
    date: "August 11, 2026",
    changes: [
      "Double-press your shortcut to lock hands-free recording on; press again to stop.",
      "Dictation errors now explain what went wrong and how to fix it.",
      "Setup verifies your speech model before finishing and safely retries interrupted downloads.",
      "Optional local cleanup can restore short words dropped by transcription.",
    ],
  },
  {
    version: "0.1.0",
    date: "August 11, 2026",
    changes: [
      "Rhino is born: hold Fn to dictate, release to insert into any app.",
      "On-device Whisper and Parakeet transcription with optional embedded AI cleanup.",
      "Local history, writing stats, and a personal dictionary for names and jargon.",
      "No remote speech engine, no remote AI cleanup, and no telemetry.",
    ],
  },
];

export default function Changelog() {
  return (
    <main className="text-page">
      <a className="back-link" href="/">← Rhino</a>
      <h1>Changelog</h1>
      <p className="page-intro">
        What&apos;s new in Rhino: every release, in plain language. The app
        updates itself automatically.
      </p>
      {releases.map((release) => (
        <section className="release" key={release.version}>
          <div className="release-heading">
            <h2>{release.version}</h2>
            <time>{release.date}</time>
          </div>
          <ul>
            {release.changes.map((change) => <li key={change}>{change}</li>)}
          </ul>
        </section>
      ))}
    </main>
  );
}
