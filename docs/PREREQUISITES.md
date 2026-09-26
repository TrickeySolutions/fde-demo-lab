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

## 2. Add + activate the apex zone
The free plan only supports **full (apex) zones** — subdomain zones are
Enterprise-only, so we use an apex such as `fde-demo.trickey.solutions` and
change its nameservers.
- Dashboard → **Add a domain** → enter the apex → choose the **Free** plan.
- Copy the two assigned Cloudflare nameservers and set them at the registrar
  (or delegate via NS records at the parent).
- Wait for the zone to show **Active** (`dig NS <zone>` returns Cloudflare NS).
- Only then set `zone_enabled = true` and re-apply.
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

## 7. Azure httpbin origin — assignment steps 1–3
- You already run httpbin on Azure App Service (free tier), e.g.
  `trick-httpbin-demo-uk-south.azurewebsites.net`.
- To make **Full (Strict)** validate for `httpbin.<zone>`, add the subdomain as
  an App Service **custom domain** and enable the **free App Service Managed
  Certificate** (or plan an origin SNI override). Then lock inbound to
  Cloudflare IPs. Full detail: `ORIGIN-AZURE.md`.

## 8. Local UTM VM — assignment step 4
- A Windows (or Linux) VM in UTM running Docker + `cloudflared`. Full detail:
  `ORIGIN-TUNNEL-VM.md`.

---

### Apply order summary
1. Steps 1,3,4,5 done → `zone_enabled = false` apply (account-level infra +
   tunnel + Access apps).
2. Bring the tunnel up on the VM (step 8) using `tofu output -raw tunnel_token`.
3. Step 2 done (zone Active) → set `zone_enabled = true`, re-apply (DNS + TLS).
4. `upload-flags.sh` → `deploy-worker.sh`.
5. Configure Azure origin (step 7) and test.
