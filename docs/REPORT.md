# Application Services Assignment — Written Report

**Author:** David Trickey · Principle Solutions Engineer (Cloudflare, UK&I Public Sector)
**Domain:** `fde-demo.trickey.solutions`
**Repositories (all public):**
- [`fde-demo-lab`](https://github.com/TrickeySolutions/fde-demo-lab) — this repo: Infrastructure-as-Code (OpenTofu), the `/secure` Worker, the click-ops guide and this report.
- [`fde-demo-deck`](https://github.com/TrickeySolutions/fde-demo-deck) — the interactive presentation (itself a Cloudflare Worker) that **live-tests** and **observes** the environment.
- [`fde-demo-origin`](https://github.com/TrickeySolutions/fde-demo-origin) — a tiny, dependency-free live-reload origin used behind the Tunnel to demonstrate that the origin is genuinely a local machine.

> **Free-tier vs. the live demo.** The assignment targets the **Free plan**, and
> every step in this repo is written to run on a Free-plan apex zone. The *live*
> demo runs on an enterprise account purely for presentation convenience —
> (a) delegated sub-domain DNS, (b) enabling R2 without putting a card on file,
> and (c) Origin Rules/Snippets so I can reuse existing demo origins. None of
> those are required to satisfy the assignment; the documented build stands on
> its own on Free tier.

---

## Summary

I put the full Cloudflare application-services chain in front of an HTTP
header-echo origin (**httpbin**): authoritative **DNS + proxy**, end-to-end TLS
in **Full (Strict)** validating a **non-Cloudflare** origin certificate, a
**Cloudflare Tunnel** publishing a private origin with no public inbound, **Zero
Trust Access** locking `/secure` to me + `@cloudflare.com` + a live-editable
list, and a **Worker** that returns the authenticated identity and serves a
country flag from a **private R2 bucket**.

I built it **two ways on purpose**:

1. **Click-ops** — the literal deliverable, documented click-by-click in
   [`CLICKOPS.md`](CLICKOPS.md) with screenshot evidence, reproducible by anyone
   on a Free plan.
2. **Infrastructure-as-code** — the same result as OpenTofu + Wrangler in this
   repo, because IaC is what makes an FDE engagement repeatable, reviewable in
   PRs, and tearable-down — i.e. something a customer's platform team can own.

And crucially, the acceptance tests are **live and automated** (§ *Validation*),
not screenshots alone — the same checks run in the demo, from a terminal, or in
CI/CD.

---

## 2a. Steps followed, with configuration + testing evidence

Full click-by-click detail and screenshot slots are in [`CLICKOPS.md`](CLICKOPS.md);
the requirement-by-requirement matrix is in
[`REQUIREMENTS-COVERAGE.md`](REQUIREMENTS-COVERAGE.md). The IaC file that
implements each step is cited inline, and every requirement has a **live check**
(§ *Validation*) so the evidence is executable, not just visual.

### Pre-requisites — zone on Cloudflare
Added `fde-demo.trickey.solutions` to Cloudflare and activated it by changing the
registrar nameservers. *(IaC operates on the already-active zone;
[`PREREQUISITES.md`](PREREQUISITES.md) lists the genuinely-manual one-offs.)*
- Live check: `dns-ns` — nameservers are `*.ns.cloudflare.com`.
- Docs: <https://developers.cloudflare.com/dns/zone-setups/full-setup/>

### Step 1 — Origin that returns all request headers
**httpbin**'s `/headers` returns every inbound HTTP header in the response body.
It runs on **Azure App Service** (public origin) and, for the Tunnel, on a local
VM (`go-httpbin` / the `fde-demo-origin` live-reload app).
- Live check: `headers` — `GET https://httpbin.<zone>/headers` is `200` and
  echoes headers, including the `Cf-*` headers Cloudflare injects.
- Evidence: `![httpbin /headers](img/01-httpbin-headers.png)`
- Docs: <https://developers.cloudflare.com/fundamentals/reference/http-headers/>

### Step 2 — Proxy through Cloudflare
Proxied (orange-cloud) DNS for `httpbin.<zone>` → the Azure origin; Cloudflare
terminates TLS at the edge, adds `Cf-*` headers, and applies zone settings.
*(IaC: [`terraform/10-dns.tf`](../terraform/10-dns.tf).)*
- Live check: `dns-proxied` — the hostname resolves to Cloudflare anycast, so the
  origin IP is hidden.
- Evidence: `![Proxied DNS record](img/02-dns-proxied.png)`
- Docs: <https://developers.cloudflare.com/dns/proxy-status/>

### Step 3 — Full (Strict) TLS with a non-Cloudflare certificate
Zone SSL/TLS mode is **Full (Strict)**, so Cloudflare validates the origin
certificate. The Azure origin presents a publicly-trusted (non-Cloudflare)
App Service managed certificate for the hostname. *(IaC:
[`terraform/00-zone.tf`](../terraform/00-zone.tf) `ssl = "strict"`; origin detail
in [`ORIGIN-AZURE.md`](ORIGIN-AZURE.md).)*
- Live checks: `ssl-mode` (Cloudflare API confirms `strict`) **and** `ssllabs`
  (independent **Qualys SSL Labs** grade — I don't mark my own homework).
- Evidence: `![SSL Full Strict](img/03-ssl-full-strict.png)`, `![SSL Labs grade](img/03-ssllabs.png)`
- Docs: <https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/>

### Step 4 — Cloudflare Tunnel on `tunnel.<zone>`
A remotely-managed Tunnel; `cloudflared` runs on the VM and **dials out**, so the
origin has **no public inbound**. Ingress routes `tunnel.<zone>` to the local
origin. *(IaC: [`terraform/50-tunnel.tf`](../terraform/50-tunnel.tf) with
`config_src = "cloudflare"`; VM steps in [`ORIGIN-TUNNEL-VM.md`](ORIGIN-TUNNEL-VM.md).)*
- Live check: `tunnel` — `GET https://tunnel.<zone>/headers` succeeds only when
  the connector is up (it honestly fails red when it isn't).
- Evidence: `![Tunnel healthy](img/04-tunnel-healthy.png)`, `![tunnel /headers](img/04-tunnel-headers.png)`
- Docs: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>

### Step 5 — SSO IdP in Zero Trust
Configured **Google** as the SSO IdP (Cloudflare corporate email is Google
Workspace, so `@cloudflare.com` users sign in with Google) and kept **One-time
PIN** so any attendee can sign in with an emailed code. *(IaC:
[`terraform/20-identity.tf`](../terraform/20-identity.tf).)*
- Evidence: `![IdPs configured](img/05-idps.png)`, `![Login screen](img/05-login.png)`
- Docs: <https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/google/>

### Step 6 — Lock down `/secure`; prevent bypass
A path-scoped **Access** application on `tunnel.<zone>/secure` with an allow
policy of: my email, `email_domain = cloudflare.com`, and a **live-editable
attendee list**. Everyone else is denied. Bypass is prevented three ways: the
`/secure` origin is only reachable via the Tunnel (no public IP); the Azure
public origin is locked to **Cloudflare egress IP ranges**; and **Authenticated
Origin Pulls** ensure the origin trusts only Cloudflare. *(IaC:
[`terraform/40-access-secure.tf`](../terraform/40-access-secure.tf),
[`30-access-lists.tf`](../terraform/30-access-lists.tf),
[`70-origin-security.tf`](../terraform/70-origin-security.tf); live list via
[`scripts/add-attendee.sh`](../scripts/add-attendee.sh).)*
- Live check: `access` — an unauthenticated request to `/secure` is redirected to
  the Cloudflare Access login (challenged, not served).
- Evidence: `![Access policy](img/06-access-policy.png)`, `![Allowed](img/06-allowed.png)`,
  `![Denied](img/06-denied.png)`, `![Direct origin blocked](img/06-bypass-blocked.png)`
- Docs: <https://developers.cloudflare.com/cloudflare-one/policies/access/>

### Step 7 — The Worker (Wrangler + private R2)
Built with the **Wrangler CLI** (`secure-worker/`), served on
`tunnel.<zone>/secure*` via a Worker route.
- **7a–7b, 7d-ii:** `/secure` reads the Access-injected
  `Cf-Access-Authenticated-User-Email`, timestamps the request, reads
  `request.cf.country`, and returns **HTML**:
  `${EMAIL} authenticated at ${TIMESTAMP} from ${COUNTRY}`.
- **7c:** `${COUNTRY}` is an HTML link to `/secure/${COUNTRY}`.
- **7d, 7d-iii:** `/secure/${COUNTRY}` streams the flag from the **private R2
  bucket** `fde-demo-flags` with the appropriate `image/svg+xml` content type.
- **7d-i:** the Worker code is in a public git repo, created via Wrangler.
  *(Route IaC kept as a commented alternative in
  [`terraform/80-worker-route.tf`](../terraform/80-worker-route.tf); Wrangler owns
  the Worker to avoid dual-writer drift — see [`IAC-VS-CLICKOPS.md`](IAC-VS-CLICKOPS.md).)*
- Live check: `flag` — the Worker reads `gb.svg` from the **private** bucket
  (no public bucket access).
- Evidence: `![/secure identity](img/07-secure-identity.png)`, `![flag](img/07-flag.png)`,
  `![private R2 bucket](img/07-r2-private.png)`
- Docs: <https://developers.cloudflare.com/workers/> ·
  <https://developers.cloudflare.com/r2/api/workers/workers-api-reference/> ·
  <https://developers.cloudflare.com/workers/runtime-apis/request/#incomingrequestcfproperties>

---

## Validation — the tests are live and automated

The demo deck is **itself a Worker**, so it can independently interrogate the
deployed environment and prove each requirement — DNS-over-HTTPS, live HTTP
probes, the Cloudflare API, an external grader (Qualys SSL Labs), a redirect
probe, and a private-R2 read. The API token it uses is a **server-side Worker
secret**, never exposed to the browser.

Every check is also exposed as one aggregate endpoint so it doubles as a
**post-deploy / CI-CD gate**:

```bash
# Human-readable table + pass/fail exit code
BASE_URL=https://deck.fde-demo.trickey.solutions ./scripts/verify.sh

# Raw machine-readable result (for pipelines)
curl -s https://deck.fde-demo.trickey.solutions/api/checks/run | jq
```

```
  ✅ [Connect] Zone runs on Cloudflare
  ✅ [Connect] Origin IP hidden behind Cloudflare
  ✅ [Connect] Origin returns all request headers
  ✅ [Connect] Reachable via Cloudflare Tunnel
  ✅ [Protect] Full (Strict) TLS to origin
  ✅ [Protect] Independent TLS grade (A/A+)          ← Qualys SSL Labs
  ✅ [Protect] /secure locked by Zero Trust Access
  ✅ [Build]   Worker serves flag from private R2
  Summary: 8 passed · 0 failed → exit 0
```

`verify.sh` exits non-zero if any check hard-fails, so in a pipeline this runs
after `tofu apply` / `wrangler deploy` as the acceptance stage. The same checks
could be promoted to a **Cloudflare Workflow** on a schedule for continuous
conformance — the primitive is already here.

---

## Beyond the brief — observability

To show that Cloudflare gives you **visibility into everything** (and that if any
test above had failed I'd have the diagnostics to hand), the deck includes a
custom **Observability** dashboard built from Cloudflare's **GraphQL Analytics
API + REST**: requests over time by status class; a host → path → content-type
Sankey; DNS lookups, data served and cache ratio; Zero Trust Access apps, logins
and users; Tunnel health; and Workers executions, p50 latency and errors — all in
one pane, re-queried over 6h / 24h / 7d. The point for a customer: you are **not
constrained by the dashboard**; you can pull exactly the data your use case needs
into your own view.

---

## 2b. Relevant use cases for the products

| Product | What it did here | Real customer use case |
| --- | --- | --- |
| **DNS + proxy** | Front the origin, hide its IP, add edge TLS + `Cf-*` headers | Authoritative DNS; a single control point for every hostname |
| **SSL/TLS (Full-Strict)** | Validated encryption edge→origin against a real cert | No plaintext/unauthenticated hop to origin; meet compliance |
| **Rules / Snippets** | Shape & transform traffic at the edge | Redirects, rewrites, header/origin control without origin changes |
| **Cloudflare Tunnel** | Publish a private origin with no inbound ports | Reach private/on-prem/cloud apps with no public IP, VPN or firewall holes |
| **Zero Trust Access (ZTNA)** | Identity-gated a path to specific users | Replace VPN for app access; SSO + policy per app/path; verify every request |
| **Identity (Google/OTP)** | SSO + contractor-friendly OTP fallback | Federate the corporate IdP; time-boxed access for externals |
| **Workers** | Identity-aware response + asset serving at the edge | Auth-aware APIs, personalisation, edge middleware, glue logic |
| **R2 (private)** | Store + serve assets, private by default, no egress fees | Media/asset storage fronted by a Worker, never publicly exposed |
| **Analytics (GraphQL/REST)** | One custom operational dashboard | Bespoke reporting, SLOs and alerting across every product |

Together these are the **connectivity cloud** story, and the architecture is an
**evolution on one fabric**: publish public resources → add private resources over
a Tunnel → verify identity with Zero Trust → and ultimately run the app itself
**serverless** on Workers + R2 — the day-to-day of an FDE engagement.

---

## 2c. How I filled gaps in my knowledge

- **Free-plan zone limits.** I assumed I could delegate a sub-domain as its own
  zone; the DNS docs showed sub-domain zones are **Enterprise-only**, so the
  Free-tier build uses an apex zone.
  (<https://developers.cloudflare.com/dns/zone-setups/>)
- **Full-Strict + Azure SNI.** I confirmed Full (Strict) validates the cert for
  the *requested* hostname, which drove the App Service custom-domain managed
  certificate rather than the bare `*.azurewebsites.net` cert.
- **Tunnel vs Full-Strict.** A Tunnel is already an encrypted outbound
  connection, so the tunnel origin needs no separately-trusted cert — Full-Strict
  is a distinct demonstration on the *public* origin.
- **Terraform provider v5.** The provider was rewritten (`cloudflare_access_*` →
  `cloudflare_zero_trust_*`, new object-attribute syntax); I verified exact
  schemas from `tofu providers schema -json` rather than trusting old examples.
- **Access identity in a Worker.** I confirmed the Access-injected
  `Cf-Access-Authenticated-User-Email` header is the simplest reliable identity
  source behind Access (with the signed JWT available for stricter verification).
- **GraphQL Analytics field names.** For the observability dashboard I validated
  the exact datasets/dimensions live against the API (e.g. `dnsAnalyticsAdaptiveGroups`,
  `httpRequestsAdaptiveGroups` `originIP`/`edgeResponseContentTypeName`,
  `workersInvocationsAdaptive`) before building the aggregation.

My method throughout: read the current dev docs / provider schema first,
prototype small (the Worker was validated locally with `wrangler dev` against a
seeded local R2 object), then codify and add a live check that proves it.

---

## 2d. How a target customer will find this experience

- **Fast "aha".** DNS + proxy + Full-Strict + an identity-gated app is a same-day
  exercise; the value (hide origin, encrypt to origin, gate by identity) lands
  immediately.
- **Tunnel removes the hardest objection.** "I can't expose this box" stops being
  a blocker — no inbound ports, no VPN, it works from a laptop.
- **The dashboard is guided; the friction is external.** The registrar nameserver
  change, the origin-side certificate/SNI detail, and enabling R2 are the real
  snags. An FDE earns trust by naming those up front (as this report does) rather
  than hitting them live.
- **IaC changes the conversation.** Handing over `tofu apply` + `wrangler deploy`
  — plus an honest list of the few manual steps and an **automated acceptance
  test** — turns a demo into something the customer's platform team can own,
  review in PRs and tear down. That is what makes them comfortable adopting it.

---

## Appendix — repository map

```
fde-demo-lab/                     # this repo — IaC, Worker, docs
  terraform/                      # OpenTofu, numbered by concern
    00-zone · 10-dns · 20-identity · 30-access-lists · 40-access-secure
    41-access-deck-admin · 50-tunnel · 60-r2 · 70-origin-security · 80-worker-route
  secure-worker/                  # the /secure Worker (Wrangler)
  scripts/                        # bootstrap, deploy-worker, upload-flags,
                                  # add-attendee, vm-setup-*, verify.sh
  docs/                           # this report + CLICKOPS, REQUIREMENTS-COVERAGE,
                                  # IAC-VS-CLICKOPS, ORIGIN-*, PREREQUISITES, DEMO-RUNBOOK
fde-demo-deck/                    # interactive presentation Worker: live /api/checks + observability
fde-demo-origin/                  # dependency-free live-reload origin for the Tunnel demo
```

- **Validation:** `./scripts/verify.sh` (or `GET /api/checks/run`).
- **Tooling split rationale:** [`IAC-VS-CLICKOPS.md`](IAC-VS-CLICKOPS.md).
- **Requirement matrix:** [`REQUIREMENTS-COVERAGE.md`](REQUIREMENTS-COVERAGE.md).
</content>
