# rhinovoice.app

The public launch site for Rhino, the private on-device dictation app for
macOS. It is a single-page vinext site deployed through Sites and connected to
the `rhinovoice.app` Cloudflare zone.

## Local development

Requires Node.js 22.13 or newer.

```bash
npm install
npm run dev
```

Run `npm test` before publishing. The production download URL is kept in
`app/page.tsx`; update it when a new Rhino release ships.
