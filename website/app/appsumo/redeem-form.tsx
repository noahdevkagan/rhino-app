"use client";

import { FormEvent, useEffect, useRef, useState } from "react";

const downloadUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/download/v0.1.39/Rhino-0.1.39.dmg";

/** SendFox form 296340 → list 678908 "Rhino AppSumo customers". Optional; only posted for a valid code. */
const emailAction = "https://sendfox.com/form/03zne3/3oywpv";

type Status = "loading" | "ready" | "invalid" | "unavailable" | "success";

function normalizeCode(value: string) {
  return value.trim().toUpperCase().replace(/\s+/g, "");
}

async function sha256(value: string) {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", data);

  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export default function RedeemForm() {
  const [status, setStatus] = useState<Status>("loading");
  const [code, setCode] = useState("");
  const [email, setEmail] = useState("");
  const hashes = useRef<Set<string> | null>(null);

  useEffect(() => {
    let active = true;

    fetch("/appsumo-hashes.json")
      .then((response) => {
        if (!response.ok) throw new Error("Unable to load redemption codes");
        return response.json() as Promise<string[]>;
      })
      .then((values) => {
        if (!active) return;
        hashes.current = new Set(values);
        setStatus("ready");
      })
      .catch(() => {
        if (active) setStatus("unavailable");
      });

    return () => {
      active = false;
    };
  }, []);

  async function redeem(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const normalizedCode = normalizeCode(code);

    if (!normalizedCode || !hashes.current) return;

    const digest = await sha256(normalizedCode);
    const valid = hashes.current.has(digest);
    setStatus(valid ? "success" : "invalid");
    if (valid && email.trim()) subscribe(email.trim(), normalizedCode);
  }

  /** Fire-and-forget: the email is optional, so a SendFox hiccup must never block the unlock.
   * The list signup keeps the address; /appsumo/email sends the buyer their code. */
  function subscribe(address: string, redeemedCode: string) {
    fetch("/appsumo/email", {
      method: "POST",
      body: JSON.stringify({ email: address, code: redeemedCode }),
      headers: { "Content-Type": "application/json" },
      keepalive: true,
    }).catch(() => {});
    const data = new FormData();
    data.append("email", address);
    fetch(emailAction, {
      method: "POST",
      body: data,
      headers: { "X-Requested-With": "XMLHttpRequest", Accept: "application/json" },
      keepalive: true,
    }).catch(() => {});
  }

  if (status === "success") {
    return (
      <section className="redemption-card redemption-success" aria-live="polite">
        <span className="success-check" aria-hidden="true">✓</span>
        <p className="redemption-eyebrow">Code redeemed</p>
        <h1>You&apos;re in.</h1>
        <ol className="unlock-steps">
          <li>
            <a className="button button-primary download-button" href={downloadUrl}>
              Download Rhino for Mac
            </a>
            <span>Open the DMG and drag Rhino to Applications.</span>
          </li>
          <li>
            <a
              className="button button-primary"
              href={`rhinovoice://unlock?code=${encodeURIComponent(normalizeCode(code))}`}
            >
              Unlock Rhino
            </a>
            <span>Once Rhino is installed, click this. Rhino opens already unlimited.</span>
          </li>
        </ol>
        <p className="redemption-help">
          Requires macOS 14 or later on Apple silicon. Need help?{" "}
          <a href="mailto:noahkagan@gmail.com">Email Noah</a>.
        </p>
      </section>
    );
  }

  const isLoading = status === "loading";
  const isUnavailable = status === "unavailable";

  return (
    <section className="redemption-card">
      <div className="appsumo-badge">APPSUMO CUSTOMER</div>
      <h1>Redeem your Rhino code.</h1>
      <p className="redemption-copy">
        Enter the code from your AppSumo purchase to download Rhino for Mac.
      </p>
      <form className="redemption-form" onSubmit={redeem}>
        <label htmlFor="redemption-code">AppSumo redemption code</label>
        <input
          id="redemption-code"
          className="redemption-input"
          value={code}
          onChange={(event) => {
            setCode(event.target.value.toUpperCase());
            if (status === "invalid") setStatus("ready");
          }}
          placeholder="RH-XXXX-XXXX-XXXX"
          autoComplete="off"
          autoCapitalize="characters"
          spellCheck={false}
          maxLength={24}
          aria-describedby={status === "invalid" || isUnavailable ? "redemption-message" : undefined}
          aria-invalid={status === "invalid"}
        />
        <label htmlFor="redemption-email">Email (optional)</label>
        <input
          id="redemption-email"
          className="redemption-email"
          type="email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="Email me my code (optional)"
          autoComplete="email"
        />
        <button
          className="button button-primary redemption-button"
          type="submit"
          disabled={isLoading || isUnavailable || !code.trim()}
        >
          {isLoading ? "Getting ready…" : "Redeem code"}
        </button>
      </form>
      {status === "invalid" && (
        <p className="redemption-error" id="redemption-message" role="alert">
          That code doesn&apos;t look right. Check for typos and try again.
        </p>
      )}
      {isUnavailable && (
        <p className="redemption-error" id="redemption-message" role="alert">
          Redemption is temporarily unavailable. Please refresh and try again.
        </p>
      )}
      <p className="redemption-help">
        Trouble redeeming?{" "}
        <a href="mailto:noahkagan@gmail.com">noahkagan@gmail.com</a>
      </p>
    </section>
  );
}
