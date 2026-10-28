/**
 * Can this visitor's Mac run Rhino? Rhino ships arm64 only and needs macOS 14+.
 * An Intel Mac can't show our own message (the app never launches), so the site
 * has to catch it before the download. See decisions.md 2026-10-27.
 *
 * Pure: everything here takes plain inputs so tests can feed sample browsers.
 * No network, no storage, no analytics. The browser-side reader lives in
 * app/_components/mac-check.tsx.
 */

export type MacSupport =
  /** Apple Silicon and macOS 14+ both confirmed. */
  | "supported"
  /** An Intel Mac: Rhino can't run here at all. */
  | "intel"
  /** macOS 13 or older (and not known to be Intel). */
  | "old-macos"
  /** A Mac, but the browser won't say enough (Safari, Firefox). */
  | "unknown"
  /** Windows, Linux, ChromeOS, phones, iPads. */
  | "not-mac";

export type MacSignals = {
  userAgent: string;
  maxTouchPoints?: number;
  /** navigator.userAgentData.getHighEntropyValues(): "arm" or "x86" (Chromium only).
   * Chromium reports the hardware here ("arm" even under Rosetta), so it is the primary signal. */
  architecture?: string;
  /** Same source. On macOS this is the real version, e.g. "13.6.1" or "14.5.0". */
  platformVersion?: string;
  /** WebGL UNMASKED_RENDERER_WEBGL (or RENDERER). Only read when there is no architecture
   * hint. Safari says "Apple GPU" on every Mac; Firefox may say "Mozilla" or "Generic Renderer". */
  webglRenderer?: string | null;
};

export type MacVerdict = {
  support: MacSupport;
  /** The macOS major version when we know it (only Chromium tells us). */
  macosMajor?: number;
  /** Apple Silicon confirmed (used to say "update macOS" instead of "can't run"). */
  appleSilicon?: boolean;
};

export const MIN_MACOS_MAJOR = 14;

/** Same rules the hero's platform check has always used. */
export function isMacDesktop(userAgent: string, maxTouchPoints = 0): boolean {
  if (/Android|iPhone|iPad|iPod/.test(userAgent)) return false;
  if (!/Macintosh|Mac OS X/.test(userAgent)) return false;
  // iPadOS reports itself as a Mac; a touch screen gives it away.
  return maxTouchPoints <= 1;
}

/** "intel" / "apple" from a WebGL renderer string, or undefined when it doesn't say. */
export function chipFromRenderer(renderer?: string | null): "intel" | "apple" | undefined {
  if (!renderer) return undefined;
  // Chrome: "ANGLE (Apple, ANGLE Metal Renderer: Apple M2 Pro, ...)". Firefox: "Apple M1, or similar".
  if (/\bApple M\d/i.test(renderer)) return "apple";
  // Every Intel-era Mac GPU: Intel integrated, AMD/ATI Radeon, older NVIDIA.
  if (/\b(Intel|AMD|ATI|Radeon|NVIDIA|GeForce)\b/i.test(renderer)) return "intel";
  return undefined;
}

/** "intel" / "apple" from userAgentData.architecture. */
export function chipFromArchitecture(architecture?: string): "intel" | "apple" | undefined {
  if (!architecture) return undefined;
  if (/^x86/i.test(architecture)) return "intel";
  if (/^arm/i.test(architecture)) return "apple";
  return undefined;
}

/** macOS major version: 13, 14, 26, or 10 for 10.x. Undefined when unknown. */
export function macosMajorFrom(platformVersion?: string, userAgent = ""): number | undefined {
  const fromHints = platformVersion?.match(/^(\d+)(?:[._](\d+))?/);
  if (fromHints) {
    const major = Number(fromHints[1]);
    const minor = Number(fromHints[2] ?? 0);
    // "10.16" is the compatibility version macOS 11+ reports to apps built on an
    // old SDK; it hides the real version, so treat it as unknown.
    if (major === 10 && minor >= 16) return undefined;
    if (major > 0) return major;
  }
  // Safari and Firefox freeze the UA at "10_15_7" / "10.15", which says nothing.
  // Anything older than 10.15 in the UA is real, though, and definitely too old.
  const fromUa = userAgent.match(/Mac OS X (\d+)[._](\d+)/);
  if (fromUa) {
    const major = Number(fromUa[1]);
    const minor = Number(fromUa[2]);
    if (major === 10 && minor < 15) return 10;
    if (major >= 11) return major;
  }
  return undefined;
}

export function classifyMac(signals: MacSignals): MacVerdict {
  const { userAgent, maxTouchPoints = 0 } = signals;
  if (!isMacDesktop(userAgent, maxTouchPoints)) return { support: "not-mac" };

  // Architecture first: Chromium reports the hardware ("arm" even for a browser
  // running under Rosetta). The WebGL renderer only fills in when there is no
  // architecture hint. If both are present and disagree (say "arm" plus a spoofed
  // "Intel" renderer), we can't trust either, so we don't block: "unknown".
  const archChip = chipFromArchitecture(signals.architecture);
  const rendererChip = chipFromRenderer(signals.webglRenderer);
  if (archChip && rendererChip && archChip !== rendererChip) return { support: "unknown" };
  const chip = archChip ?? rendererChip;
  let macosMajor = macosMajorFrom(signals.platformVersion, userAgent);
  // Apple Silicon shipped with macOS 11, so a 10.x report on arm is an old-SDK quirk.
  if (chip === "apple" && macosMajor === 10) macosMajor = undefined;
  const appleSilicon = chip === "apple";

  if (chip === "intel") return { support: "intel", macosMajor };
  if (macosMajor !== undefined && macosMajor < MIN_MACOS_MAJOR) {
    return { support: "old-macos", macosMajor, appleSilicon };
  }
  if (appleSilicon && macosMajor !== undefined) return { support: "supported", macosMajor, appleSilicon };
  return { support: "unknown", macosMajor, appleSilicon };
}

/** True when the download button should give way to the "can't run" message. */
export function isUnsupported(verdict: MacVerdict): boolean {
  return verdict.support === "intel" || verdict.support === "old-macos";
}
