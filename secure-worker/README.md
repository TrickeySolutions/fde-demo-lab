# fde-demo-secure — Access-protected identity Worker

The Cloudflare Worker for **assignment step 7**. Built and deployed with the
**Wrangler CLI**, served on `tunnel.<zone>/secure*` behind Cloudflare Access.

## Routes

| Path | Response | Content-Type |
| --- | --- | --- |
| `/secure` | `${EMAIL} authenticated at ${TIMESTAMP} from ${COUNTRY}` as HTML, where `${COUNTRY}` links to `/secure/${COUNTRY}` | `text/html` |
| `/secure/${COUNTRY}` | the country flag, streamed from the **private R2 bucket** | `image/svg+xml` |

- `${EMAIL}` comes from the `Cf-Access-Authenticated-User-Email` header that
  Cloudflare Access injects after authenticating the request.
- `${COUNTRY}` comes from `request.cf.country` (Cloudflare geo).
- The flag SVGs live in the private `fde-demo-flags` R2 bucket (created by
  Terraform in `../terraform/60-r2.tf`), reachable only via the `FLAGS` binding.

## Develop

```bash
npm install
npm run check                       # tsc --noEmit
# seed a local flag + run locally:
../scripts/upload-flags.sh --local gb us
npm run dev                         # http://localhost:8787
curl -H "Cf-Access-Authenticated-User-Email: you@example.com" localhost:8787/secure
curl localhost:8787/secure/gb
```

## Deploy

```bash
# after the zone is Active and flags are uploaded to the real bucket:
../scripts/upload-flags.sh gb us ie fr de
npm run deploy                      # publishes script + route + R2 binding
npm run tail                        # live logs
```

The route pattern in `wrangler.jsonc` must match the `tunnel_hostname` +
`secure_path` in the Terraform variables. Change both together if you rename.

## Why Wrangler (not Terraform) owns this

The Worker **code**, its **route** and its **R2 binding** are one deployable
unit and change together, so a single `wrangler deploy` keeps them consistent.
Terraform owns the surrounding platform (zone, DNS, Access, Tunnel, the R2
bucket resource itself). See `../docs/IAC-VS-CLICKOPS.md`.
