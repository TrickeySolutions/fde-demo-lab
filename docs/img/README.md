# Screenshot capture checklist

Save each capture here in `docs/img/` with the **exact filename** below (PNG,
retina/2× is fine). They back the "configuration and testing evidence" the
assignment asks for, mapped to the steps in `../REPORT.md`.

Tip: crop to the relevant panel, and where a URL/hostname or a status word
("Active", "Healthy", "Full (strict)") proves the point, make sure it's legible.

---

## Pre-requisites
- **`00-zone-active.png`** — Cloudflare dashboard → the `fde-demo.trickey.solutions`
  **Overview**, showing status **Active** and the assigned `*.ns.cloudflare.com`
  nameservers.

## Step 1 — Origin returns all request headers
- **`01-headers-public.png`** — browser at
  `https://httpbin.fde-demo.trickey.solutions/headers`, response body visible with
  the **`Cf-Ray` / `Cf-Connecting-Ip` / `Cf-Ipcountry`** headers highlighted.

## Step 2 — Proxy through Cloudflare
- **`02-dns-proxied.png`** — dashboard → **DNS → Records**, the `httpbin` record
  with the **orange cloud (Proxied)** clearly on.

## Step 3 — Full (Strict) TLS with a non-Cloudflare certificate
- **`03-ssl-full-strict.png`** — **SSL/TLS → Overview**, encryption mode set to
  **Full (strict)**.
- **`03-origin-cert.png`** — the **origin** certificate details (Azure App Service
  custom-domain managed cert): issuer = a public CA, **CN/SAN =
  `httpbin.fde-demo.trickey.solutions`** (browser cert viewer on the origin, or the
  Azure portal custom-domain blade).
- **`03-ssllabs-aplus.png`** — the **Qualys SSL Labs** report page for
  `httpbin.fde-demo.trickey.solutions` showing the **A+** grade.

## Step 4 — Cloudflare Tunnel on `tunnel.<zone>`
- **`04-tunnel-healthy.png`** — **Zero Trust → Networks → Tunnels**, the tunnel row
  showing **HEALTHY** with its connector(s).
- **`04-tunnel-served.png`** — browser at `https://tunnel.fde-demo.trickey.solutions/`
  showing the local origin served through the Tunnel (the `fde-demo-origin` page, or
  `/headers`).

## Step 5 — SSO Identity Provider in Zero Trust
- **`05-idps.png`** — **Zero Trust → Settings → Authentication**, login methods
  showing **Google** and **One-time PIN**.
- **`05-login-screen.png`** — the Cloudflare Access **login screen** presented at
  `/secure`, with the Google and OTP options.

## Step 6 — Lock down `/secure` and prevent bypass
- **`06-access-policy.png`** — **Zero Trust → Access → Applications →** the
  `/secure` app, the **Allow** policy showing: your email, `@cloudflare.com` email
  domain, and the attendee list.
- **`06-secure-denied.png`** — a **non-allowed** identity hitting `/secure` and
  getting the Access **"do not have access"** page.
- **`06-bypass-blocked.png`** — a terminal: `curl` straight to the **Azure origin
  IP/hostname** returning **403** (egress-IP allowlist + Authenticated Origin
  Pulls), proving the origin can't be reached directly.

## Step 7 — The Worker (Wrangler + private R2)
- **`07-secure-identity.png`** — an **authenticated** `/secure` response: the HTML
  `${EMAIL} authenticated at ${TIMESTAMP} from ${COUNTRY}`, with `${COUNTRY}` as a
  link. (This is also your "allowed" evidence for Step 6.)
- **`07-flag.png`** — `https://tunnel.fde-demo.trickey.solutions/secure/GB` rendering
  the **GB flag** SVG.
- **`07-r2-private.png`** — **R2 →** the `fde-demo-flags` bucket, **Public access =
  disabled** (private) with the flag object(s) listed.
- **`07-worker-route.png`** *(optional)* — **Workers & Pages →** `fde-demo-secure`
  with the route `tunnel.fde-demo.trickey.solutions/secure*`.

## Validation — tests are live and automated
- **`08-verify-run.png`** — a terminal running `./scripts/verify.sh` (or
  `curl …/api/checks/run | jq`) showing the pass/fail table and exit code.
- **`08-deck-output.png`** — the deck's interactive **Output** slide
  (`deck.fde-demo.trickey.solutions`) with the requirement checks ticked green.

## Beyond the brief — the deck (optional but strong)
- **`09-architecture.png`** — the deck **Architecture** slide (one of the evolution
  phases, e.g. Identity verified).
- **`09-observability.png`** — the deck **Observability** dashboard (the Sankey +
  live stats pulled from the Cloudflare API).

---

### Filename index (for quick reference)
```
00-zone-active.png
01-headers-public.png
02-dns-proxied.png
03-ssl-full-strict.png   03-origin-cert.png   03-ssllabs-aplus.png
04-tunnel-healthy.png    04-tunnel-served.png
05-idps.png              05-login-screen.png
06-access-policy.png     06-secure-denied.png     06-bypass-blocked.png
07-secure-identity.png   07-flag.png   07-r2-private.png   07-worker-route.png (optional)
08-verify-run.png        08-deck-output.png
09-architecture.png      09-observability.png   (optional)
```
