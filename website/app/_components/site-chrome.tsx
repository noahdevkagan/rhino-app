const paypalAction = "https://www.paypal.com/cgi-bin/webscr";

/** The one Rhino price. The PayPal form and every comparison page read it. */
export const rhinoPrice = 20;

/** The current DMG. Release scripts check this file links the version being shipped. */
export const downloadUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases/download/v0.1.34/Rhino-0.1.34.dmg";

export const releasesUrl =
  "https://github.com/noahdevkagan/rhino-releases/releases";

export function RhinoMark({ size = 42 }: { size?: number }) {
  return (
    <span
      className="rhino-mark"
      style={{ width: size, height: size, fontSize: Math.round(size * 0.62) }}
      aria-hidden="true"
    >
      🦏
    </span>
  );
}

export function BuyForm({ compact = false }: { compact?: boolean }) {
  return (
    <form className={compact ? "buy-form buy-form-compact" : "buy-form"} action={paypalAction} method="post">
      <input type="hidden" name="cmd" value="_xclick" />
      <input type="hidden" name="business" value="paypal@okdork.com" />
      <input type="hidden" name="item_name" value="Rhino for Mac" />
      <input type="hidden" name="amount" value={rhinoPrice.toFixed(2)} />
      <input type="hidden" name="currency_code" value="USD" />
      <input type="hidden" name="no_shipping" value="1" />
      <input type="hidden" name="return" value="https://rhinovoice.app/thanks" />
      <input type="hidden" name="cancel_return" value="https://rhinovoice.app/" />
      <button className={compact ? "button button-compact" : "button button-primary"} type="submit">
        {compact ? `Buy for $${rhinoPrice}` : `Buy Rhino for $${rhinoPrice}`}
      </button>
    </form>
  );
}

export function DownloadButton({ compact = false }: { compact?: boolean }) {
  return (
    // /get redirects to the DMG: the download starts in place, and Cloudflare counts
    // website downloads separately from Sparkle updates (which fetch the DMG directly).
    <a className={compact ? "button button-compact" : "button button-primary"} href="/get">
      {compact ? "Download free" : "Download Rhino free"}
    </a>
  );
}

export function SiteHeader() {
  return (
    <header className="site-header">
      <a className="brand" href="/" aria-label="Rhino home">
        <RhinoMark />
        <span>Rhino Voice</span>
      </a>
      <nav aria-label="Main navigation">
        <a href="/changelog">Changelog</a>
        <DownloadButton compact />
      </nav>
    </header>
  );
}

export function SiteFooter() {
  return (
    <footer>
      <span>Rhino Voice</span>
      <a href="mailto:noahkagan@gmail.com">Email</a>
      <a href="/changelog">Changelog</a>
      <a href="/vs/wispr-flow">Rhino Voice vs Wispr Flow</a>
      <a href="/best">Dictation app guides</a>
      <a href={releasesUrl}>Releases on GitHub</a>
      <a href="https://meetmouse.com/">Also by me: MeetMouse, private meeting notes</a>
    </footer>
  );
}
