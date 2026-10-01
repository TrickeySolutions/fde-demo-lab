# Prerequisites — the one-time manual steps

These are the steps Cloudflare does not expose to automation (account signup,
zone activation, enabling Zero Trust/R2, the OAuth app). Do them once, then the
Terraform + Wrangler in this repo does the rest. Each links to the relevant
Cloudflare docs.

As you go, **record the values you choose or are given** — they are the Terraform
inputs. Copy `terraform/terraform.tfvars.example` → `terraform.tfvars` and fill in
the non-secret ones; put secrets in `.envrc` (both gitignored). Don't hardcode
them anywhere else.

| Value | Terraform input | Where it lives | Secret |
| --- | --- | --- | --- |
| Account ID | `cloudflare_account_id` | `terraform.tfvars` | no |
| API token | `cloudflare_api_token` | `.envrc` → `TF_VAR_cloudflare_api_token` | **yes** |
| Apex domain | `zone_name` | `terraform.tfvars` | no |
| Zero Trust team name | `team_name` | `terraform.tfvars` (must match dashboard) | no |
| Your admin email | `self_email` | `terraform.tfvars` | no |
| Allowed email domain | `cloudflare_email_domain` | `terraform.tfvars` | no |
| Public origin hostname | `azure_origin_hostname` | `terraform.tfvars` | no |
| Google OAuth client ID | `google_client_id` | `terraform.tfvars` | no |
| Google OAuth client secret | `google_client_secret` | `.envrc` → `TF_VAR_google_client_secret` | **yes** |

The demo hostnames (`httpbin_hostname`, `tunnel_hostname`, `deck_hostname`) default
to names under `zone_name`; override them only if you want different labels.

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
- The **team name you choose must match `team_name`** in `terraform.tfvars`; the
  auth domain becomes `<team-name>.cloudflareaccess.com`. It can't be changed
  later without pain, so pick it deliberately.
- Pick the **Free** Zero Trust plan (covers up to 50 users — ample here).
- Docs: <https://developers.cloudflare.com/cloudflare-one/setup/>

## 4. Enable R2
- Dashboard → **R2** → enable. This may prompt for a payment method even though
  usage stays within the always-free tier (10 GB storage / class-A+B ops).
- No bucket to create by hand — Terraform creates the private flags bucket
  (name set by `flags_bucket_name`).
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

Scope the zone rows to **your** zone (`zone_name`). Put the token in `.envrc` as
`TF_VAR_cloudflare_api_token` (and mirror to `CLOUDFLARE_API_TOKEN`) — never in tfvars.
- Docs: <https://developers.cloudflare.com/fundamentals/api/get-started/create-token/>

## 6. (Optional) Google OAuth app for SSO — assignment step 5
Only needed if `google_idp_enabled = true`. One-time PIN works without it.
- Google Cloud Console → APIs & Services → **Credentials** → **Create OAuth
  client ID** → *Web application*.
- Authorized redirect URI: `https://<team-name>.cloudflareaccess.com/cdn-cgi/access/callback`
  (using the `team_name` from step 3).
- Copy the client ID → `google_client_id` (tfvars); client secret →
  `TF_VAR_google_client_secret` (env var, never committed).
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
publicly-trusted certificate for the hostname and lock inbound to
[Cloudflare's published IP ranges](https://www.cloudflare.com/ips/).

## 8. Run the origin locally for the Tunnel — assignment step 4
The Tunnel origin is the **same `origin-app/`** running on my own machine — a
**Mac laptop**, no VM required (a VM works identically). On macOS:
```bash
node origin-app/server.mjs                                    # http://localhost:8080
cloudflared tunnel run --token "$(tofu -chdir=terraform output -raw tunnel_token)"
```
`cloudflared` dials out, so nothing is exposed inbound.

---

### Order of operations

The one thing that needs sequencing is the zone: nameserver changes (step 2) take
time to go **Active**, and some resources can't be created until they are. So the
apply happens in **two passes**, gated by `zone_enabled`.

1. **Do the prerequisites (1–6)** and fill `terraform.tfvars` + `.envrc`. Kick off
   the nameserver change (step 2) early — it propagates while you continue.
2. **First apply with `zone_enabled = false`** — everything that doesn't need the
   zone active: Zero Trust org + IdP, lists, Access apps, the Tunnel, and R2.
3. **Start the origin + Tunnel** (steps 7–8): run `origin-app`, then
   `cloudflared tunnel run --token "$(tofu -chdir=terraform output -raw tunnel_token)"`.
4. **Once the zone shows Active** (`dig NS <your-domain>`), set
   `zone_enabled = true` and **apply again** — adds DNS, Full (Strict) TLS and the
   Worker route.
5. **Publish the app:** `scripts/upload-flags.sh` then `scripts/deploy-worker.sh`.
6. **Validate:** `scripts/verify.sh` (or open the live hostnames).
