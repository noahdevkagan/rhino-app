"use client";

import { useState } from "react";

/** Big unlock code with a one-click copy, so buyers never hunt for it. */
export function CopyCode({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="unlock-code">
      <code>{code}</code>
      <button
        type="button"
        className="button"
        onClick={() => {
          navigator.clipboard?.writeText(code).then(
            () => setCopied(true),
            () => setCopied(false),
          );
        }}
      >
        {copied ? "Copied ✓" : "Copy code"}
      </button>
    </div>
  );
}
