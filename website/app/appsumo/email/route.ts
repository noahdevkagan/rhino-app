import { downloadUrl } from "../../_components/site-chrome";

/** Rhino's AppSumo redeem form posts here after a valid code: we email the buyer their code
 * via SendFox transactional (Noah's account, from okdork.com). Needs the SENDFOX_TOKEN secret. */
const sendFoxUrl = "https://api.sendfox.com/transactional/emails";
const from = "Noah from Rhino <noah@okdork.com>";

type Env = { ASSETS?: { fetch(request: Request): Promise<Response> }; SENDFOX_TOKEN?: string };

function normalizeCode(value: string) {
  return value.trim().toUpperCase().replace(/\s+/g, "");
}

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Same hash list the browser checks, so only real codes ever trigger an email. */
async function isValidCode(code: string, request: Request, env: Env) {
  const url = new URL("/appsumo-hashes.json", request.url);
  const response = env.ASSETS ? await env.ASSETS.fetch(new Request(url)) : await fetch(url);
  if (!response.ok) return false;
  const hashes = (await response.json()) as string[];
  return hashes.includes(await sha256(code));
}

function message(code: string, origin: string) {
  const unlockUrl = `${origin}/appsumo/unlock?code=${encodeURIComponent(code)}`;
  const text = `Thanks for getting Rhino on AppSumo.

Your code: ${code}

1. Download Rhino for Mac: ${downloadUrl}
2. Unlock it: ${unlockUrl}
   (or in Rhino choose "Get Rhino Unlimited" and enter your code)

Keep this email. Your code works on any Mac you use.

Reply if you get stuck.
Noah`;
  const button = "display:inline-block;padding:12px 20px;border-radius:10px;background:#ff705f;color:#fff;text-decoration:none;font-weight:600";
  const html = `<div style="font-family:-apple-system,Helvetica,Arial,sans-serif;font-size:16px;line-height:1.6;color:#241c18;max-width:520px">
<p>Thanks for getting Rhino on AppSumo.</p>
<p>Your code:<br><strong style="font-family:Menlo,monospace;font-size:20px;letter-spacing:1px">${code}</strong></p>
<p><a href="${downloadUrl}" style="${button}">Download Rhino for Mac</a></p>
<p><a href="${unlockUrl}" style="${button}">Unlock Rhino</a><br>
<span style="font-size:14px;color:#6f625b">Or in Rhino choose “Get Rhino Unlimited” and enter your code.</span></p>
<p>Keep this email. Your code works on any Mac you use.</p>
<p>Reply if you get stuck.<br>Noah</p>
</div>`;
  return { text, html };
}

export async function POST(request: Request) {
  const env = ((globalThis as { __rhinoEnv?: Env }).__rhinoEnv ?? {}) as Env;
  const body = (await request.json().catch(() => null)) as { email?: unknown; code?: unknown } | null;
  const email = typeof body?.email === "string" ? body.email.trim() : "";
  const code = typeof body?.code === "string" ? normalizeCode(body.code) : "";

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254 || !code || code.length > 24) {
    return Response.json({ ok: false, error: "invalid_input" }, { status: 400 });
  }
  if (!(await isValidCode(code, request, env))) {
    return Response.json({ ok: false, error: "invalid_code" }, { status: 400 });
  }
  if (!env.SENDFOX_TOKEN) {
    console.error("appsumo email not sent: SENDFOX_TOKEN is not configured");
    return Response.json({ ok: false, error: "not_configured" }, { status: 503 });
  }

  const { text, html } = message(code, new URL(request.url).origin);
  const response = await fetch(sendFoxUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SENDFOX_TOKEN}`,
      "Content-Type": "application/json",
      Accept: "application/json",
      // One email per code + address, however many times they click Redeem.
      "Idempotency-Key": `rhino-appsumo-${await sha256(`${code}:${email.toLowerCase()}`)}`,
    },
    body: JSON.stringify({ from, to: [email], reply_to: "noah@okdork.com", subject: "Your Rhino code", text, html, tag: "rhino_appsumo_code" }),
  });
  if (!response.ok) {
    console.error("appsumo email not sent", response.status, await response.text().catch(() => ""));
    return Response.json({ ok: false, error: "send_failed" }, { status: 502 });
  }
  return Response.json({ ok: true });
}
