# Requirements coverage

Every assignment requirement mapped to how this environment meets it, where it
lives in code, and how to test it. `<zone>` = `fde-demo.trickey.solutions`.

## Pre-requisites

| # | Requirement | How met | Where |
| --- | --- | --- | --- |
| P1 | Free plan account | Free account created | `PREREQUISITES.md` §1 |
| P2 | Add a domain | Apex zone `<zone>` added (free = apex only) | `PREREQUISITES.md` §2 |
| P3 | Change nameservers | NS delegated at parent; zone Active | `PREREQUISITES.md` §2 |

## Steps

| # | Requirement | How met | Where | Test |
| --- | --- | --- | --- | --- |
| 1 | Origin returns all request headers | httpbin `/headers` on Azure App Service (or `origin-app/`) | `origin-app/`, `PREREQUISITES.md` | `curl https://httpbin.<zone>/headers` |
| 2 | Proxy traffic through Cloudflare | Proxied CNAME `httpbin.<zone>` → Azure | `terraform/10-dns.tf` | orange cloud; `Cf-*` headers present |
| 3 | Full-Strict TLS with non-Cloudflare cert | `ssl = "strict"`; Azure managed cert for the hostname | `terraform/00-zone.tf` | `openssl s_client` issuer = Azure |
| 4 | Cloudflare Tunnel on `tunnel.<zone>` | Remotely-managed tunnel + ingress to the local origin | `terraform/50-tunnel.tf`, `PREREQUISITES.md` | `curl https://tunnel.<zone>/headers` |
| 5 | SSO IdP in Zero Trust | Google OAuth (SSO) + One-time PIN | `terraform/20-identity.tf` | login screen offers Google/OTP |
| 6 | Lock down a path to self + `@cloudflare.com`; no bypass | Access app on `tunnel.<zone>/secure`; Tunnel + Azure IP lock prevent bypass | `terraform/40-access-secure.tf`, `70-origin-security.tf` | allowed vs denied users; direct origin blocked |
| 6b | Live-editable allow-list | Zero Trust email list + `add-attendee.sh` | `terraform/30-access-lists.tf`, `scripts/add-attendee.sh` | add email live → immediate access |
| 7 | Create a Worker (Wrangler) | `fde-demo-secure` built + deployed with Wrangler | `secure-worker/` | `wrangler deploy` |
| 7a | `/secure` returns identity for the authed user | reads `Cf-Access-Authenticated-User-Email` | `secure-worker/src/index.ts` | body shows the signed-in email |
| 7b | Body = `${EMAIL} authenticated at ${TIMESTAMP} from ${COUNTRY}` | exact string composed | `secure-worker/src/index.ts` | inspect `/secure` HTML |
| 7c | `${COUNTRY}` is a link to `/secure/${COUNTRY}` showing the flag | anchor to `/secure/<code>` | `secure-worker/src/index.ts` | click the country link |
| 7d | Flag stored in a **private** R2 bucket | private `fde-demo-flags`; served only via binding | `terraform/60-r2.tf`, `scripts/upload-flags.sh` | no public r2.dev; Worker serves it |
| 7d-i | Worker via Wrangler CLI; code in public git repo | Wrangler; repo is public | `secure-worker/`, repo | GitHub URL |
| 7d-ii | `/secure` returned as HTML | `content-type: text/html` | `secure-worker/src/index.ts` | response headers |
| 7d-iii | `/secure/${COUNTRY}` appropriate content type | `content-type: image/svg+xml` | `secure-worker/src/index.ts` | response headers |

## Test matrix (run after full apply + deploy)

```bash
Z=fde-demo.trickey.solutions

# 1/2/3 — proxied httpbin + Full-Strict
curl -sS https://httpbin.$Z/headers | jq '.headers | keys'          # request headers returned
echo | openssl s_client -connect trick-httpbin-demo-uk-south.azurewebsites.net:443 \
  -servername httpbin.$Z 2>/dev/null | openssl x509 -noout -issuer  # non-Cloudflare issuer

# 4 — tunnel
curl -sS https://tunnel.$Z/headers | jq '.headers.Host'             # served via tunnel

# 6 — access + no bypass
curl -sS -o /dev/null -w "%{http_code}\n" https://tunnel.$Z/secure  # 302/redirect to Access when unauthenticated
curl -sS -o /dev/null -w "%{http_code}\n" \
  https://trick-httpbin-demo-uk-south.azurewebsites.net/headers     # 403/timeout (locked)

# 7 — worker (after signing in through Access in a browser)
#   /secure       -> HTML "email authenticated at ts from XX" (Content-Type text/html)
#   /secure/GB    -> flag (Content-Type image/svg+xml)
```

## Known constraints / honest notes
- **Free plan = apex zone only** (subdomain zones are Enterprise). We use an
  apex; hostnames are `httpbin.`, `tunnel.`, `deck.` under it.
- **R2** may require a payment method to enable, though usage stays free-tier.
- **Full-Strict on Azure** needs the custom-domain managed cert (or SNI
  override) so the presented cert matches the requested hostname.
- **Access on a pending zone** must be re-saved (re-applied) once the zone is
  Active.
