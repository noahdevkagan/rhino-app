"use client";

import { useEffect, useState, type ReactNode } from "react";
import { classifyMac, isUnsupported, type MacVerdict } from "../_lib/mac-support";

/**
 * Browser half of the "can this Mac run Rhino?" check (rules in _lib/mac-support.ts).
 * Reads only what the browser already knows: no network, no storage, no analytics.
 * Server render and first paint are "unknown", so the requirement line is in the HTML
 * for Safari, Firefox and no-JS visitors.
 */

type UADataLike = {
  getHighEntropyValues?: (hints: string[]) => Promise<{ architecture?: string; platformVersion?: string }>;
};

async function highEntropyHints(): Promise<{ architecture?: string; platformVersion?: string }> {
  const uaData = (navigator as Navigator & { userAgentData?: UADataLike }).userAgentData;
  if (!uaData?.getHighEntropyValues) return {};
  try {
    const timeout = new Promise<Record<string, never>>((resolve) => setTimeout(() => resolve({}), 800));
    return await Promise.race([uaData.getHighEntropyValues(["architecture", "platformVersion"]), timeout]);
  } catch {
    return {};
  }
}

function webglRenderer(): string | null {
  try {
    const canvas = document.createElement("canvas");
    const gl = (canvas.getContext("webgl") ?? canvas.getContext("experimental-webgl")) as WebGLRenderingContext | null;
    if (!gl) return null;
    const debug = gl.getExtension("WEBGL_debug_renderer_info");
    const renderer = gl.getParameter(debug ? debug.UNMASKED_RENDERER_WEBGL : gl.RENDERER);
    gl.getExtension("WEBGL_lose_context")?.loseContext();
    return typeof renderer === "string" ? renderer : null;
  } catch {
    return null;
  }
}

let pending: Promise<MacVerdict> | null = null;

/** One check per page load, however many buttons ask. */
export function checkMac(): Promise<MacVerdict> {
  if (!pending) {
    pending = (async () => {
      const userAgent = navigator.userAgent;
      const base = classifyMac({ userAgent, maxTouchPoints: navigator.maxTouchPoints });
      if (base.support === "not-mac") return base;
      const hints = await highEntropyHints();
      return classifyMac({
        userAgent,
        maxTouchPoints: navigator.maxTouchPoints,
        architecture: hints.architecture,
        platformVersion: hints.platformVersion,
        webglRenderer: webglRenderer(),
      });
    })().catch((): MacVerdict => ({ support: "unknown" }));
  }
  return pending;
}

export function useMacVerdict(): MacVerdict {
  const [verdict, setVerdict] = useState<MacVerdict>({ support: "unknown" });
  useEffect(() => {
    let active = true;
    checkMac().then((result) => {
      if (active) setVerdict(result);
    });
    return () => {
      active = false;
    };
  }, []);
  return verdict;
}

export const requirementText =
  "Needs a Mac with Apple Silicon (M1 or newer) and macOS 14+. Check: Apple menu > About This Mac > Chip.";

export function MacRequirement() {
  return <p className="mac-requirement">{requirementText}</p>;
}

export function UnsupportedMacNotice({
  verdict,
  downloadHref,
  appsumo = false,
}: {
  verdict: MacVerdict;
  /** Omit where there's no download yet (the AppSumo code form). */
  downloadHref?: string;
  appsumo?: boolean;
}) {
  const intel = verdict.support === "intel";
  const version = verdict.macosMajor ? `macOS ${verdict.macosMajor}` : "an older macOS";

  return (
    <div className="mac-unsupported" role="status">
      <p className="mac-unsupported-title">
        {intel ? "This Mac can't run Rhino." : "Rhino needs macOS 14 or later."}
      </p>
      {intel ? (
        <p>
          Rhino needs a Mac with Apple Silicon (M1 or newer) and macOS 14+. This Mac looks
          like it has an Intel chip, so Rhino won&apos;t open on it. Sorry about that.
        </p>
      ) : verdict.appleSilicon ? (
        <p>
          Your Mac has Apple Silicon but is on {version}. Update macOS first (Apple menu {">"}{" "}
          System Settings {">"} General {">"} Software Update), then come back and download Rhino.
        </p>
      ) : (
        <p>
          This Mac is on {version}. If it has an M1 or newer chip, update macOS (Apple menu{" "}
          {">"} System Settings {">"} General {">"} Software Update), then download Rhino. If it
          has an Intel chip, Rhino can&apos;t run on it.
        </p>
      )}
      <p>
        Check your Mac: Apple menu {">"} About This Mac. Chip should say Apple M1 or newer, and
        macOS should be 14 or later.
      </p>
      {appsumo ? (
        <p>
          Bought Rhino on AppSumo and your Mac can&apos;t run it? Get a refund in your AppSumo
          account: Products {">"} Rhino Voice {">"} Refund.
        </p>
      ) : null}
      {downloadHref ? (
        <p className="mac-download-anyway">
          <a href={downloadHref}>Download anyway</a> (if we got your Mac wrong)
        </p>
      ) : null}
    </div>
  );
}

export function NotMacNote({ children }: { children?: ReactNode }) {
  return (
    <p className="mac-requirement">
      {children ?? "Rhino is Mac only. Open this page on your Mac to download it."}
    </p>
  );
}

/**
 * Wraps a download button. Apple Silicon + macOS 14 confirmed: just the button.
 * Unknown: the button plus the one-line requirement. Intel or old macOS: the
 * friendly "can't run" message with a small "Download anyway" link.
 */
export function MacDownloadGate({
  href,
  children,
  appsumo = false,
  notMac,
}: {
  href: string;
  children: ReactNode;
  appsumo?: boolean;
  notMac?: ReactNode;
}) {
  const verdict = useMacVerdict();

  if (isUnsupported(verdict)) {
    return <UnsupportedMacNotice verdict={verdict} downloadHref={href} appsumo={appsumo} />;
  }
  if (verdict.support === "not-mac") {
    return (
      <>
        {children}
        <NotMacNote>{notMac}</NotMacNote>
      </>
    );
  }
  return (
    <>
      {children}
      {verdict.support === "supported" ? null : <MacRequirement />}
    </>
  );
}

/**
 * The small "Download free" buttons on content pages and in the header. They keep
 * their look everywhere; on a Mac that can't run Rhino they lead to /download,
 * which explains why, instead of starting a DMG that won't open.
 */
export function DownloadLink({ className, children }: { className: string; children: ReactNode }) {
  const verdict = useMacVerdict();
  return (
    <a className={className} href={isUnsupported(verdict) ? "/download" : "/get"}>
      {children}
    </a>
  );
}
