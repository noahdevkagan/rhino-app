"use client";

import { useEffect, useState } from "react";

/** SendFox form 296020 → list 678242 "Rhino Windows waitlist". Redirects back with ?waitlist=windows. */
const waitlistAction = "https://sendfox.com/form/03zne3/1dxeg5";
/** SendFox form 296025 → list 678250; automation 122583 emails the /get link at once. Redirects back with ?sent=mac. */
const sendToMacAction = "https://sendfox.com/form/03zne3/1ww6y6";

type Platform = "mac" | "phone" | "desktop-other" | "joined" | "sent";

/** Rhino is Mac-only. Phones get "email me the link" so they can install from their Mac
 * later; Windows/Linux/ChromeOS desktops get a waitlist instead of a DMG they can't open. */
function detectPlatform(): Platform {
  const params = new URLSearchParams(window.location.search);
  if (params.get("waitlist") === "windows") return "joined";
  if (params.get("sent") === "mac") return "sent";
  const ua = navigator.userAgent;
  // iPadOS reports itself as a Mac; a touch screen gives it away.
  if (/Android|iPhone|iPad|iPod/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1)) return "phone";
  if (/Windows|CrOS|Linux/.test(ua)) return "desktop-other";
  return "mac";
}

/** Posts to SendFox in the background: a SendFox submit takes ~3s server-side, then the
 * redirect reloads the page. Instead we show the done state at once and only fall back
 * to the form if SendFox rejects the address. Without JS the plain form post still works. */
function EmailForm({ title, action, button, note, done }: {
  title: string;
  action: string;
  button: string;
  note: React.ReactNode;
  done: React.ReactNode;
}) {
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);

  function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const data = new FormData(event.currentTarget);
    setError(null);
    setSent(true);
    fetch(action, {
      method: "POST",
      body: data,
      headers: { "X-Requested-With": "XMLHttpRequest", Accept: "application/json" },
      keepalive: true,
    })
      .then(async (response) => {
        if (response.status === 422) {
          const body = await response.json().catch(() => null);
          setSent(false);
          setError(body?.errors?.[0] ?? "That email didn't work. Try again?");
        }
      })
      .catch(() => {});
  }

  if (sent) return <>{done}</>;

  return (
    <div className="waitlist">
      <p className="waitlist-title">{title}</p>
      <form className="waitlist-form" action={action} method="post" onSubmit={submit}>
        <label className="visually-hidden" htmlFor="cta-email">Email</label>
        <input id="cta-email" type="email" name="email" placeholder="you@example.com" required autoComplete="email" />
        {/* SendFox honeypot: real people never see or fill it. */}
        <input type="text" name="a_password" tabIndex={-1} autoComplete="off" aria-hidden="true" className="visually-hidden" />
        <button className="button" type="submit">{button}</button>
      </form>
      {error && <p className="purchase-note" role="alert">{error}</p>}
      <p className="purchase-note">{note}</p>
    </div>
  );
}

function JoinedWaitlist() {
  return (
    <div className="waitlist">
      <p className="waitlist-title">You&apos;re on the Windows list.</p>
      <p className="purchase-note">Check your inbox to confirm. We&apos;ll email you once when Rhino runs on Windows.</p>
    </div>
  );
}

function SentToMac() {
  return (
    <div className="waitlist">
      <p className="waitlist-title">Check your email.</p>
      <p className="purchase-note">Open it on your Mac and tap the download link. If you don&apos;t see it, check spam or confirm your email first.</p>
    </div>
  );
}

export function HeroCta() {
  // Server render and first paint assume a Mac: that's half the traffic and all the installs.
  const [platform, setPlatform] = useState<Platform>("mac");
  useEffect(() => setPlatform(detectPlatform()), []);

  if (platform === "joined") return <JoinedWaitlist />;
  if (platform === "sent") return <SentToMac />;

  if (platform === "phone") {
    return (
      <EmailForm
        title="Rhino runs on your Mac. Get the link there."
        action={sendToMacAction}
        button="Email me the link"
        note="We'll email you the download link to open on your Mac."
        done={<SentToMac />}
      />
    );
  }

  if (platform === "desktop-other") {
    return (
      <EmailForm
        title="Rhino is Mac-only for now."
        action={waitlistAction}
        button="Notify me"
        note={<>Get one email when Rhino comes to Windows. On a Mac too? <a href="/get">Download for Mac</a>.</>}
        done={<JoinedWaitlist />}
      />
    );
  }

  return (
    // /get redirects to the DMG; see DownloadButton.
    <a className="button button-primary button-hero" href="/get">
      Download Rhino free
    </a>
  );
}
