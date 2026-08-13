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

Run `npm test` before publishing. The production download URLs are kept in
`app/thanks/page.tsx` and `app/appsumo/redeem-form.tsx`; update both when a new
Rhino release ships.

## AppSumo redemption codes

The `/appsumo` page validates codes against the SHA-256 hashes in
`public/appsumo-hashes.json`; plaintext codes never ship with the site or enter
Git. The private upload batch is generated into the workspace's ignored
`.context/` directory:

```bash
cd website
node scripts/generate-appsumo-codes.mjs
```

The generator refuses to replace an existing batch unless `--force` is passed.
