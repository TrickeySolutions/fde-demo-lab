# Application Services Assignment — Written Report

**Author:** David Trickey
**Domain:** `fde-demo.trickey.solutions` (Cloudflare Free plan)
**Repos:** `fde-demo-lab` (this repo — IaC, Worker, docs) · `fde-demo-deck` (demo)

> Screenshots referenced as `![…](img/…)` are captured live from the working
> environment; capture checklists are in each `ORIGIN-*.md` and `CLICKOPS.md`.
> Every product claim links to the Cloudflare developer docs used.

---

## Summary

I built a working environment that takes an HTTP-header-echo origin (httpbin)
and puts the full Cloudflare application-services chain in front of it: DNS +
proxy, end-to-end TLS in **Full (Strict)** to a non-Cloudflare origin
certificate, a **Cloudflare Tunnel** for a private origin with no public
inbound, **Zero Trust Access** locking a path to me + `@cloudflare.com` + a
live-editable list, and a **Worker** that returns the authenticated identity and
serves a country flag from a **private R2 bucket**.

I did it twice on purpose: as **click-by-click dashboard steps** (this report +
`CLICKOPS.md`, the literal deliverable) and as **infrastructure-as-code**
(OpenTofu + Wrangler in this repo), because the IaC version is what makes the
result repeatable and handover-ready — the mindset an FDE brings to a customer.

---

## 2a. Steps followed, with configuration + testing evidence

Full click-by-click detail with screenshot slots is in `CLICKOPS.md`; the
requirement-by-requirement mapping and test commands are in
`REQUIREMENTS-COVERAGE.md`. The IaC equivalent of every step is cited inline.

### Step 1 — Origin that returns all request headers
httpbin's `/headers` returns every inbound HTTP header in the response body. I
run it as a container on **Azure App Service** (free tier) and, for the tunnel,
in **Docker on a local UTM VM**.
- Evidence: `![httpbin /headers](img/01-httpbin-headers.png)`
- Docs: <https://developers.cloudflare.com/fundamentals/reference/http-headers/>

### Step 2 — Proxy through Cloudflare
Proxied (orange-cloud) CNAME `httpbin.<zone>` → the Azure origin. Cloudflare now
terminates TLS at the edge, adds `Cf-*` request headers, and applies zone
settings. *(IaC: `terraform/10-dns.tf`.)*
- Evidence: `![Proxied DNS record](img/02-dns-proxied.png)`
- Docs: <https://developers.cloudflare.com/dns/proxy-status/>

### Step 3 — Full (Strict) TLS with a non-Cloudflare certificate
Set the zone SSL/TLS mode to **Full (Strict)**, so Cloudflare validates the
origin certificate. The origin presents the Azure-issued (publicly trusted,
non-Cloudflare) certificate for `httpbin.<zone>` via an App Service custom-domain
managed certificate. *(IaC: `terraform/00-zone.tf` `ssl = "strict"`; detail in
`ORIGIN-AZURE.md`.)*
- Evidence: `![SSL Full Strict](img/03-ssl-full-strict.png)`,
  `![Origin cert issuer](img/03-origin-issuer.png)`
- Docs: <https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/>

### Step 4 — Cloudflare Tunnel on `tunnel.<zone>`
A remotely-managed Cloudflare Tunnel; `cloudflared` runs on the UTM VM and dials
out, so the VM origin has **no public inbound**. Ingress routes `tunnel.<zone>`
to the dockerised httpbin. *(IaC: `terraform/50-tunnel.tf`; VM steps in
`ORIGIN-TUNNEL-VM.md`.)*
- Evidence: `![Tunnel healthy](img/04-tunnel-healthy.png)`,
  `![tunnel /headers](img/04-tunnel-headers.png)`
- Docs: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>

### Step 5 — SSO IdP in Zero Trust
Configured **Google** as the SSO IdP (Cloudflare corporate email is Google
Workspace, so `@cloudflare.com` users sign in with Google) and kept **One-time
PIN** so any attendee email can log in with an emailed code. *(IaC:
`terraform/20-identity.tf`.)*
- Evidence: `![IdPs configured](img/05-idps.png)`, `![Login screen](img/05-login.png)`
- Docs: <https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/google/>

### Step 6 — Lock down `/secure`; prevent bypass
A path-scoped Access application on `tunnel.<zone>/secure` with an allow policy
including: my email, `email_domain = cloudflare.com`, and a live-editable
attendee list. Non-listed users are denied. Bypass is prevented because
`/secure` sits behind the Tunnel (no origin IP) and the Azure origin is locked
to Cloudflare IP ranges. *(IaC: `terraform/40-access-secure.tf`,
`70-origin-security.tf`; live list via `scripts/add-attendee.sh`.)*
- Evidence: `![Access policy](img/06-access-policy.png)`,
  `![Allowed](img/06-allowed.png)`, `![Denied](img/06-denied.png)`,
  `![Direct origin blocked](img/06-bypass-blocked.png)`
- Docs: <https://developers.cloudflare.com/cloudflare-one/policies/access/>

### Step 7 — The Worker
Built with the **Wrangler CLI** (`secure-worker/`), served on
`tunnel.<zone>/secure*` via a Worker route.
- `/secure` reads the Access-injected `Cf-Access-Authenticated-User-Email`,
  timestamps the request, reads `request.cf.country`, and returns **HTML**:
  `${EMAIL} authenticated at ${TIMESTAMP} from ${COUNTRY}`, where `${COUNTRY}`
  links to `/secure/${COUNTRY}` (7a–7c, 7d-ii).
- `/secure/${COUNTRY}` streams the flag from the **private R2 bucket**
  `fde-demo-flags` with `content-type: image/svg+xml` (7d, 7d-iii).
- Code is in a public git repo (7d-i).
- Evidence: `![/secure identity](img/07-secure-identity.png)`,
  `![flag](img/07-flag.png)`, `![private R2 bucket](img/07-r2-private.png)`
- Docs: <https://developers.cloudflare.com/workers/> ·
  <https://developers.cloudflare.com/r2/api/workers/workers-api-reference/> ·
  request.cf: <https://developers.cloudflare.com/workers/runtime-apis/request/#incomingrequestcfproperties>

---

## 2b. Relevant use cases for the products

| Product | What it did here | Real customer use case |
| --- | --- | --- |
| **DNS + proxy** | Front the origin, add edge TLS + `Cf-*` headers | Authoritative DNS, hide origin, single control point for every hostname |
| **SSL/TLS (Full-Strict)** | Validated encryption edge→origin | Guarantee no plaintext or unauthenticated hop to origin; meet compliance |
| **Cloudflare Tunnel** | Publish a private origin with no inbound ports | Reach private apps / on-prem / cloud VMs without a public IP, VPN, or firewall holes |
| **Zero Trust Access (ZTNA)** | Identity-gated a path to specific users | Replace VPN for app access; enforce SSO + policy per app/path |
| **Identity (Google/OTP)** | SSO + contractor-friendly OTP | Federate the corporate IdP; grant time-boxed access to externals |
| **Workers** | Identity-aware response + asset serving at the edge | Auth-aware APIs, personalisation, edge middleware, glue logic |
| **R2 (private)** | Store + serve assets without egress fees, private by default | Media/asset storage fronted by a Worker, no public bucket exposure |

Together they are the "connectivity cloud" story: connect any origin, secure it
with identity, and run logic at the edge — the day-to-day of an FDE engagement.

---

## 2c. How I filled gaps in my knowledge

- **Free-plan zone limits.** I assumed I could delegate a subdomain as its own
  zone; the DNS docs showed subdomain zones are **Enterprise-only**, so I moved
  to an apex zone. (<https://developers.cloudflare.com/dns/zone-setups/>)
- **Full-Strict + Azure SNI.** I confirmed Full (Strict) validates the cert for
  the *requested* hostname, which drove the App Service custom-domain managed
  cert (or an origin SNI override) rather than relying on the bare
  `*.azurewebsites.net` cert.
  (<https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/>)
- **Tunnel vs Full-Strict.** I clarified that a Tunnel is already an encrypted
  outbound connection, so the tunnel origin can be self-signed/loopback
  (`no_tls_verify`) — Full-Strict is a separate demonstration on the public
  origin.
- **Terraform provider v5.** The provider was rewritten (v4→v5:
  `cloudflare_access_*` → `cloudflare_zero_trust_*`, object-attribute syntax). I
  verified the exact schemas from `tofu providers schema -json` instead of
  trusting older examples.
- **Access identity in a Worker.** I confirmed the Access-injected
  `Cf-Access-Authenticated-User-Email` header is the simplest reliable identity
  source behind Access (with the JWT available for stricter verification).

My method throughout: read the current dev docs / provider schema first,
prototype small (the Worker was validated locally with `wrangler dev` and a
seeded local R2 object), then codify.

---

## 2d. How a target customer will find this experience

- **Fast for the "aha".** DNS + proxy + Full-Strict + an identity-gated app is a
  same-day exercise. The value (hide origin, encrypt to origin, gate by
  identity) lands immediately.
- **Tunnel removes the hardest objection.** "I can't expose this box" stops
  being a blocker — no inbound ports, no VPN, works from a laptop VM.
- **The dashboard is guided;** the friction points are external: the registrar
  nameserver change, the origin-side certificate/SNI detail, and enabling R2. An
  FDE earns trust by naming those up front (as this report does) rather than
  hitting them live.
- **IaC changes the conversation.** Handing over `terraform apply` + `wrangler
  deploy` (and an honest list of the few manual steps) turns a demo into
  something the customer's platform team can own, review in PRs, and tear down —
  which is exactly what makes them comfortable adopting it.
