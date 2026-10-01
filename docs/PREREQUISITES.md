# Prerequisites — the one-time manual steps

These are the steps Cloudflare does not expose to automation (account signup,
zone activation, enabling Zero Trust/R2, the OAuth app). Do them once, then the
Terraform + Wrangler in this repo does the rest. Each links to the relevant
Cloudflare docs.

## 1. Create the free Cloudflare account
- Sign up at <https://dash.cloudflare.com/sign-up> and verify the email.
- Note the **Account ID** (Dashboard → any domain → right sidebar, or
  Workers & Pages → Account details). Put it in `terraform.tfvars`
  (`cloudflare_account_id`) and `.envrc` (`CLOUDFLARE_ACCOUNT_ID`).
- Docs: <https://developers.cloudflare.com/fundamentals/setup/account/create-account/>

## 2. Add your domain and change nameservers at your registrar
Free and Pro onboard a **full apex zone** (e.g. `example.com`); subdomain-only
zones are Enterprise. On a free account:
- Dashboard → **Add a domain** → enter your **apex** domain → select **Free**.
- Review the DNS records Cloudflare imports from your current provider.
- Cloudflare shows **two nameservers** (e.g. `ada.ns.cloudflare.com` and
  `rob.ns.cloudflare.com`).
- Sign in to your **domain registrar** (GoDaddy, Namecheap, 123-reg, Cloudflare
  Registrar, etc.), open the domain's **nameserver / DNS** settings, and
  **replace** the current nameservers with Cloudflare's two. Remove any others.
- Save. Propagation is usually minutes but can take up to ~24h.
- The zone turns **Active** once Cloudflare detects the change — confirm with
  `dig NS example.com`.
- Only then set `zone_enabled = true` and re-apply.

> **Live-demo note.** This environment is published at
> `fde-demo.trickey.solutions` — a *subdomain* delegated to Cloudflare as its own
> zone, which requires Enterprise. That is purely presentation convenience; on a
> free account you onboard the apex (`trickey.solutions`) exactly as above and
> everything downstream is identical.

- Docs: <https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/> ·
  <https://developers.cloudflare.com/dns/zone-setups/>

## 3. Enable Zero Trust (Access) — set the team name
- Dashboard → **Zero Trust** → complete onboarding.
- **Team name must equal `var.team_name`** (default `fde-demo`); the auth
  domain becomes `fde-demo.cloudflareaccess.com`. This cannot be changed later
  without pain.
- Pick the **Free** Zero Trust plan (covers up to 50 users — ample here).
- Docs: <https://developers.cloudflare.com/cloudflare-one/setup/>

## 4. Enable R2
- Dashboard → **R2** → enable. This may prompt for a payment method even though
  usage stays within the always-free tier (10 GB storage / class-A+B ops).
- No bucket to create by hand — Terraform creates the private `fde-demo-flags`
  bucket.
- Docs: <https://developers.cloudflare.com/r2/get-started/> ·
  pricing <https://developers.cloudflare.com/r2/pricing/>

## 5. Create the API token
Create a **custom token** (My Profile → API Tokens → Create Token → Custom) with:

| Scope | Level | Why |
| --- | --- | --- |
| Account › Cloudflare Tunnel | Edit | create the tunnel + config |
| Account › Access: Apps and Policies | Edit | Access apps + policies |
| Account › Access: Organizations, Identity Providers, and Groups | Edit | IdPs + org |
| Account › Zero Trust | Edit | lists |
| Account › Workers R2 Storage | Edit | create bucket + upload flags |
| Account › Workers Scripts | Edit | deploy the Worker |
| Account › Account Settings | Read | account lookups |
| Zone › Zone | Edit | zone settings |
| Zone › DNS | Edit | DNS records |
| Zone › SSL and Certificates | Edit | Full-Strict + AOP |
| Zone › Zone Settings | Edit | TLS settings |

Scope the zone rows to the `fde-demo.trickey.solutions` zone. Put the token in
`.envrc` as `TF_VAR_cloudflare_api_token` (and mirror to `CLOUDFLARE_API_TOKEN`).
- Docs: <https://developers.cloudflare.com/fundamentals/api/get-started/create-token/>

## 6. (Optional) Google OAuth app for SSO — assignment step 5
Only needed if `google_idp_enabled = true`. One-time PIN works without it.
- Google Cloud Console → APIs & Services → **Credentials** → **Create OAuth
  client ID** → *Web application*.
- Authorized redirect URI: `https://<team>.cloudflareaccess.com/cdn-cgi/access/callback`
  (i.e. `https://fde-demo.cloudflareaccess.com/cdn-cgi/access/callback`).
- Copy the client ID → `google_client_id` in tfvars; client secret →
  `TF_VAR_google_client_secret` env var.
- Docs: <https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/google/>

## 7. Run the header-echo origin — assignment steps 1–3
Any origin that returns the request headers works; **Cloudflare is agnostic to
the origin host.** This repo ships a tiny, dependency-free one in
[`origin-app/`](../origin-app/) (Node 18+, nothing to install): it serves a page
plus **`/headers`** (echoes the inbound request headers) and live-reloads on save.
```bash
node origin-app/server.mjs      # serves on http://localhost:8080
```
Point your proxied DNS record (or the Tunnel) at wherever you run it.

In the deployed example the **public** origin is an implementation of **httpbin**
in a **Docker container** on a **free Azure App Service** plan — one choice of
external origin; the Cloudflare config is identical either way.
- httpbin image: <https://hub.docker.com/r/kennethreitz/httpbin>
- Azure App Service (custom container): <https://learn.microsoft.com/azure/app-service/quickstart-custom-container>

For **Full (Strict)** to validate on an external origin, give it a
publicly-trusted certificate for `httpbin.<zone>` and lock inbound to Cloudflare
IPs — detail in [`ORIGIN-AZURE.md`](ORIGIN-AZURE.md).

## 8. Run the origin locally for the Tunnel — assignment step 4
The Tunnel origin is the **same `origin-app/`** running on my own machine — a
**Mac laptop**, no VM required (a VM works identically). On macOS:
```bash
node origin-app/server.mjs                                    # http://localhost:8080
cloudflared tunnel run --token "$(tofu -chdir=terraform output -raw tunnel_token)"
```
`cloudflared` dials out, so nothing is exposed inbound. Optional VM setup:
[`ORIGIN-TUNNEL-VM.md`](ORIGIN-TUNNEL-VM.md).

---

### Apply order summary
1. Steps 1,3,4,5 done → `zone_enabled = false` apply (account-level infra +
   tunnel + Access apps).
2. Bring the tunnel up locally (step 8) using `tofu output -raw tunnel_token`.
3. Step 2 done (zone Active) → set `zone_enabled = true`, re-apply (DNS + TLS).
4. `upload-flags.sh` → `deploy-worker.sh`.
5. Run/point the public origin (step 7) and test.
