"use client";

import { useState } from "react";

/** Download, then Unlock. Unlock stays quiet (still clickable) until Download is clicked:
 * the rhinovoice:// link does nothing before Rhino is installed. Same treatment as the
 * AppSumo redeem form. */
export function UnlockSteps({ downloadUrl, unlockCode }: { downloadUrl: string; unlockCode: string }) {
  const [downloaded, setDownloaded] = useState(false);
  return (
    <ol className="unlock-steps">
      <li>
        <a
          className="button button-primary download-button"
          href={downloadUrl}
          onClick={() => setDownloaded(true)}
        >
          Download Rhino for Mac
        </a>
        <span>Open the DMG and drag Rhino to Applications. Already have Rhino? Skip to step 2.</span>
      </li>
      <li>
        <a
          className={downloaded ? "button button-primary" : "button button-quiet"}
          href={`rhinovoice://unlock?code=${unlockCode}`}
        >
          Unlock Rhino
        </a>
        <span>
          <strong>Install Rhino first, then click Unlock.</strong> One click, nothing to type. Rhino
          opens and says it&apos;s unlimited.
        </span>
      </li>
    </ol>
  );
}
