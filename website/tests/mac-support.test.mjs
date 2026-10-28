import assert from "node:assert/strict";
import test from "node:test";
import { classifyMac, macosMajorFrom } from "../app/_lib/mac-support.ts";

// Real-world strings: every Mac browser sends this frozen UA, Intel or not.
const MAC_CHROME =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
const MAC_SAFARI =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15";
const MAC_FIREFOX = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:131.0) Gecko/20100101 Firefox/131.0";
const MOJAVE_SAFARI =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.1.2 Safari/605.1.15";
const WINDOWS_CHROME =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36";
const IPHONE =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";

const M1_RENDERER = "ANGLE (Apple, ANGLE Metal Renderer: Apple M1, Unspecified Version)";
const INTEL_RENDERER = "ANGLE (Intel Inc., Intel(R) Iris(TM) Plus Graphics 655, OpenGL 4.1)";
const AMD_RENDERER = "ANGLE (ATI Technologies Inc., AMD Radeon Pro 5500M OpenGL Engine, OpenGL 4.1)";

test("Chrome on Apple Silicon with macOS 14+ is supported", () => {
  const verdict = classifyMac({ userAgent: MAC_CHROME, architecture: "arm", platformVersion: "14.5.0", webglRenderer: M1_RENDERER });
  assert.equal(verdict.support, "supported");
  assert.equal(verdict.macosMajor, 14);
  assert.equal(classifyMac({ userAgent: MAC_CHROME, architecture: "arm", platformVersion: "26.0.0" }).support, "supported");
});

test("Chrome says x86: Intel Mac", () => {
  assert.equal(classifyMac({ userAgent: MAC_CHROME, architecture: "x86", platformVersion: "14.6.1" }).support, "intel");
  // Intel beats old macOS: updating won't help.
  assert.equal(classifyMac({ userAgent: MAC_CHROME, architecture: "x86", platformVersion: "12.7.4" }).support, "intel");
});

test("WebGL renderer alone catches Intel and AMD GPUs", () => {
  assert.equal(classifyMac({ userAgent: MAC_FIREFOX, webglRenderer: INTEL_RENDERER }).support, "intel");
  assert.equal(classifyMac({ userAgent: MAC_FIREFOX, webglRenderer: AMD_RENDERER }).support, "intel");
  assert.equal(classifyMac({ userAgent: MAC_FIREFOX, webglRenderer: "Intel(R) HD Graphics, or similar" }).support, "intel");
});

test("architecture comes first; a disagreeing renderer never blocks", () => {
  // Chromium reports "arm" even under Rosetta, so arm + a spoofed Intel renderer is not Intel.
  const spoofed = classifyMac({ userAgent: MAC_CHROME, architecture: "arm", platformVersion: "14.5.0", webglRenderer: INTEL_RENDERER });
  assert.equal(spoofed.support, "unknown");
  assert.equal(classifyMac({ userAgent: MAC_CHROME, architecture: "x86", platformVersion: "14.5.0", webglRenderer: M1_RENDERER }).support, "unknown");
});

test("arm with a software renderer (SwiftShader) still counts as Apple Silicon", () => {
  const swiftShader = "ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)";
  assert.equal(classifyMac({ userAgent: MAC_CHROME, architecture: "arm", platformVersion: "15.1.0", webglRenderer: swiftShader }).support, "supported");
  assert.equal(classifyMac({ userAgent: MAC_CHROME, webglRenderer: swiftShader }).support, "unknown");
});

test("Firefox's masked renderer strings say nothing", () => {
  assert.equal(classifyMac({ userAgent: MAC_FIREFOX, webglRenderer: "Mozilla" }).support, "unknown");
  assert.equal(classifyMac({ userAgent: MAC_FIREFOX, webglRenderer: "Generic Renderer" }).support, "unknown");
});

test("hints timed out: an M1 renderer alone knows the chip, not macOS", () => {
  const verdict = classifyMac({ userAgent: MAC_CHROME, webglRenderer: M1_RENDERER });
  assert.equal(verdict.support, "unknown");
  assert.equal(verdict.appleSilicon, true);
});

test("platformVersion 10.16 (old-SDK compatibility version) is not a real version", () => {
  assert.equal(macosMajorFrom("10.16.0"), undefined);
  assert.equal(classifyMac({ userAgent: MAC_CHROME, platformVersion: "10.16.0" }).support, "unknown");
  assert.equal(classifyMac({ userAgent: MAC_CHROME, architecture: "arm", platformVersion: "10.16.0" }).support, "unknown");
});

test("arm with a 10.x macOS report is an old-SDK quirk, not an old Mac", () => {
  const verdict = classifyMac({ userAgent: MAC_CHROME, architecture: "arm", platformVersion: "10.15.7" });
  assert.equal(verdict.support, "unknown");
  assert.equal(verdict.macosMajor, undefined);
});

test("macOS 12 and 13 are too old; Apple Silicon is told to update", () => {
  const verdict = classifyMac({ userAgent: MAC_CHROME, architecture: "arm", platformVersion: "13.6.1" });
  assert.equal(verdict.support, "old-macos");
  assert.equal(verdict.macosMajor, 13);
  assert.equal(verdict.appleSilicon, true);
  const unknownChip = classifyMac({ userAgent: MAC_CHROME, platformVersion: "12.7.0" });
  assert.equal(unknownChip.support, "old-macos");
  assert.equal(unknownChip.appleSilicon, false);
});

test("a pre-10.15 UA is definitely too old, even in Safari", () => {
  assert.equal(classifyMac({ userAgent: MOJAVE_SAFARI, webglRenderer: "Apple GPU" }).support, "old-macos");
});

test("Safari's generic renderer is inconclusive", () => {
  assert.equal(classifyMac({ userAgent: MAC_SAFARI, webglRenderer: "Apple GPU" }).support, "unknown");
  assert.equal(classifyMac({ userAgent: MAC_SAFARI }).support, "unknown");
  assert.equal(classifyMac({ userAgent: MAC_SAFARI, webglRenderer: null }).support, "unknown");
});

test("Firefox on Apple Silicon knows the chip but not macOS: still inconclusive", () => {
  const verdict = classifyMac({ userAgent: MAC_FIREFOX, webglRenderer: "Apple M1, or similar" });
  assert.equal(verdict.support, "unknown");
  assert.equal(verdict.appleSilicon, true);
});

test("non-Macs and iPads are not Macs", () => {
  assert.equal(classifyMac({ userAgent: WINDOWS_CHROME, architecture: "x86", webglRenderer: INTEL_RENDERER }).support, "not-mac");
  assert.equal(classifyMac({ userAgent: IPHONE }).support, "not-mac");
  // iPadOS sends a Mac UA; the touch screen gives it away.
  assert.equal(classifyMac({ userAgent: MAC_SAFARI, maxTouchPoints: 5 }).support, "not-mac");
  assert.equal(classifyMac({ userAgent: "Mozilla/5.0 (X11; Linux x86_64)" }).support, "not-mac");
});

test("macOS version parsing", () => {
  assert.equal(macosMajorFrom("14.5.0"), 14);
  assert.equal(macosMajorFrom("13_6_1"), 13);
  assert.equal(macosMajorFrom(undefined, MAC_SAFARI), undefined);
  assert.equal(macosMajorFrom("", MAC_FIREFOX), undefined);
  assert.equal(macosMajorFrom(undefined, MOJAVE_SAFARI), 10);
});
