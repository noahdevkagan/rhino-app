const paypalAction = "https://www.paypal.com/cgi-bin/webscr";

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
      <input type="hidden" name="amount" value="20.00" />
      <input type="hidden" name="currency_code" value="USD" />
      <input type="hidden" name="no_shipping" value="1" />
      <input type="hidden" name="return" value="https://rhinovoice.app/thanks" />
      <input type="hidden" name="cancel_return" value="https://rhinovoice.app/" />
      <button className={compact ? "button button-compact" : "button button-primary"} type="submit">
        {compact ? "Buy — $20" : "Buy Rhino — $20"}
      </button>
    </form>
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
        <BuyForm compact />
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
      <a href={releasesUrl}>Releases on GitHub</a>
    </footer>
  );
}
