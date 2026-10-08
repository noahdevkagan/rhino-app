"use client";

import { useEffect, useState } from "react";

/** SendFox form 296020 → list 678242 "Rhino Windows waitlist". Redirects back with ?waitlist=windows. */
const waitlistAction = "https://sendfox.com/form/03zne3/1dxeg5";

type Platform = "mac" | "desktop-other" | "joined";

/** Rhino is Mac-only. Windows/Linux/ChromeOS desktops get a waitlist instead of a DMG
 * they can't open. Phones keep the download button (they come back on their Mac). */
function detectPlatform(): Platform {
  if (new URLSearchParams(window.location.search).get("waitlist") === "windows") return "joined";
  const ua = navigator.userAgent;
  if (/Android|iPhone|iPad|iPod/.test(ua)) return "mac";
  if (/Windows|CrOS|Linux/.test(ua)) return "desktop-other";
  return "mac";
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

  if (platform === "desktop-other") {
    return (
      <div className="waitlist">
        <p className="waitlist-title">Rhino is Mac-only for now.</p>
        <form className="waitlist-form" action={waitlistAction} method="post">
          <label className="visually-hidden" htmlFor="waitlist-email">Email</label>
          <input id="waitlist-email" type="email" name="email" placeholder="you@example.com" required autoComplete="email" />
          {/* SendFox honeypot: real people never see or fill it. */}
          <input type="text" name="a_password" tabIndex={-1} autoComplete="off" aria-hidden="true" className="visually-hidden" />
          <button className="button" type="submit">Notify me</button>
        </form>
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
