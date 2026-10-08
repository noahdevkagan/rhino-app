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

function EmailForm({ action, button }: { action: string; button: string }) {
  return (
    <form className="waitlist-form" action={action} method="post">
      <label className="visually-hidden" htmlFor="cta-email">Email</label>
      <input id="cta-email" type="email" name="email" placeholder="you@example.com" required autoComplete="email" />
      {/* SendFox honeypot: real people never see or fill it. */}
      <input type="text" name="a_password" tabIndex={-1} autoComplete="off" aria-hidden="true" className="visually-hidden" />
      <button className="button" type="submit">{button}</button>
    </form>
  );
}

export function HeroCta() {
  // Server render and first paint assume a Mac: that's half the traffic and all the installs.
  const [platform, setPlatform] = useState<Platform>("mac");
  useEffect(() => setPlatform(detectPlatform()), []);

  if (platform === "joined") {
    return (
      <div className="waitlist">
        <p className="waitlist-title">You&apos;re on the Windows list.</p>
        <p className="purchase-note">Check your inbox to confirm. We&apos;ll email you once when Rhino runs on Windows.</p>
      </div>
    );
  }

  if (platform === "sent") {
    return (
      <div className="waitlist">
        <p className="waitlist-title">Check your email.</p>
        <p className="purchase-note">Open it on your Mac and tap the download link. If you don&apos;t see it, check spam or confirm your email first.</p>
      </div>
    );
  }

  if (platform === "phone") {
    return (
      <div className="waitlist">
        <p className="waitlist-title">Rhino runs on your Mac. Get the link there.</p>
        <EmailForm action={sendToMacAction} button="Email me the link" />
        <p className="purchase-note">We&apos;ll email you the download link to open on your Mac.</p>
      </div>
    );
  }

  if (platform === "desktop-other") {
    return (
      <div className="waitlist">
        <p className="waitlist-title">Rhino is Mac-only for now.</p>
        <EmailForm action={waitlistAction} button="Notify me" />
        <p className="purchase-note">
          Get one email when Rhino comes to Windows. On a Mac too? <a href="/get">Download for Mac</a>.
        </p>
      </div>
    );
  }

  return (
    // /get redirects to the DMG; see DownloadButton.
    <a className="button button-primary button-hero" href="/get">
      Download Rhino free
    </a>
  );
}
