/** Phone visitors' "Remind me on my Mac" posts here: we send the Mac download link at once via
 * SendFox transactional (no opt-in wait). The hero also posts the address to the SendFox list
 * form (when they tick "updates") so we keep the contact. Needs the SENDFOX_TOKEN secret. */
const sendFoxUrl = "https://api.sendfox.com/transactional/emails";
const from = "Noah from Rhino <noah@okdork.com>";

type Env = { SENDFOX_TOKEN?: string };

async function sha256(value: string) {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

function message(origin: string) {
  // /get always points at the current DMG, so old emails never go stale.
  const link = `${origin}/get?src=send-to-mac`;
  const text = `Here's the Rhino reminder you asked for.

Download it: ${link}

Open this email on your Mac, tap the link, and drag Rhino to Applications.
Then hold Fn, talk, and your words show up wherever you're typing.

Reply if you get stuck.
Noah`;
  const button = "display:inline-block;padding:12px 20px;border-radius:10px;background:#ff705f;color:#fff;text-decoration:none;font-weight:600";
  const html = `<div style="font-family:-apple-system,Helvetica,Arial,sans-serif;font-size:16px;line-height:1.6;color:#241c18;max-width:520px">
<p>Here's the Rhino reminder you asked for.</p>
<p><a href="${link}" style="${button}">Download Rhino for Mac</a></p>
<p>Open this email on your Mac, tap the button, and drag Rhino to Applications. Then hold Fn, talk, and your words show up wherever you're typing.</p>
<p>Reply if you get stuck.<br>Noah</p>
</div>`;
  return { text, html };
}

export async function POST(request: Request) {
  const env = ((globalThis as { __rhinoEnv?: Env }).__rhinoEnv ?? {}) as Env;
  const body = (await request.json().catch(() => null)) as { email?: unknown; a_password?: unknown } | null;
  const email = typeof body?.email === "string" ? body.email.trim() : "";

  // Honeypot filled = bot. Pretend it worked.
  if (typeof body?.a_password === "string" && body.a_password) return Response.json({ ok: true });
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    return Response.json({ ok: false, error: "That email doesn't look right. Try again?" }, { status: 422 });
  }
  if (!env.SENDFOX_TOKEN) {
    console.error("send-to-mac email not sent: SENDFOX_TOKEN is not configured");
    return Response.json({ ok: false, error: "not_configured" }, { status: 503 });
  }

  const { text, html } = message(new URL(request.url).origin);
  const day = new Date().toISOString().slice(0, 10);
  const response = await fetch(sendFoxUrl, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.SENDFOX_TOKEN}`,
      "Content-Type": "application/json",
      Accept: "application/json",
      // At most one link email per address per day, so the form can't be used to mail-bomb someone.
      "Idempotency-Key": `rhino-send-to-mac-${await sha256(`${email.toLowerCase()}:${day}`)}`,
    },
    body: JSON.stringify({ from, to: [email], reply_to: "noah@okdork.com", subject: "Reminder: get Rhino on your Mac", text, html, tag: "rhino_send_to_mac" }),
  });
  if (!response.ok) {
    console.error("send-to-mac email not sent", response.status, await response.text().catch(() => ""));
    return Response.json({ ok: false, error: "send_failed" }, { status: 502 });
  }
  return Response.json({ ok: true });
}
