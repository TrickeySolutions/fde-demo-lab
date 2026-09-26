# ClickOps walkthrough — doing it in the dashboard

The literal assignment deliverable: how to build the environment step by step in
the Cloudflare dashboard, with a screenshot slot at each stage. This is the
"clickops" counterpart to the IaC in `terraform/` + `secure-worker/`. Each step
notes the equivalent code so you can show both.

Convention: `<zone> = fde-demo.trickey.solutions`. Drop screenshots into
`docs/img/` using the suggested filenames.

---

## 0. Prerequisites
See `PREREQUISITES.md` (account, apex zone + NS change, enable Zero Trust + R2,
API token, Google OAuth app). Do these first.

---

## 1. httpbin origin returns request headers
1. Confirm the Azure App Service httpbin responds: open
   `https://trick-httpbin-demo-uk-south.azurewebsites.net/headers`.
2. It returns all request headers as JSON in the body. ✔ step 1.
- `![01-httpbin-headers](img/01-httpbin-headers.png)`
- IaC: n/a (origin) · Docs: origin setup in `ORIGIN-AZURE.md`.

## 2. Proxy httpbin through Cloudflare
1. Dashboard → your zone → **DNS → Records → Add record**.
2. Type `CNAME`, Name `httpbin`, Target the Azure hostname, **Proxied (orange)**.
3. Save. Open `https://httpbin.<zone>/headers` — note the added `Cf-Connecting-IP`
   / `Cf-Ray` headers proving it went through Cloudflare. ✔ step 2.
- `![02-dns-proxied](img/02-dns-proxied.png)`
- IaC: `terraform/10-dns.tf` · Docs: <https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/>

## 3. Full (Strict) TLS with a non-Cloudflare cert
1. First make the origin present a valid cert for `httpbin.<zone>`: in Azure add
   it as a **custom domain** + bind the **free managed certificate**
   (`ORIGIN-AZURE.md`).
2. Dashboard → **SSL/TLS → Overview** → set encryption mode to **Full (strict)**.
3. Verify the origin cert issuer is Azure/Microsoft (non-Cloudflare) with
   `openssl s_client` (command in `ORIGIN-AZURE.md`). ✔ step 3.
- `![03-ssl-full-strict](img/03-ssl-full-strict.png)` · `![03-origin-issuer](img/03-origin-issuer.png)`
- IaC: `terraform/00-zone.tf` · Docs: <https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/>

## 4. Cloudflare Tunnel on `tunnel.<zone>`
1. Dashboard → **Zero Trust → Networks → Tunnels → Create a tunnel** →
   *Cloudflared* → name `fde-demo-tunnel`.
2. Install the connector on the VM using the shown token (`ORIGIN-TUNNEL-VM.md`).
3. Add a **Public Hostname**: subdomain `tunnel`, domain `<zone>`, service
   `http://localhost:80`. Save.
4. Open `https://tunnel.<zone>/headers`. ✔ step 4.
- `![04-tunnel-healthy](img/04-tunnel-healthy.png)` · `![04-tunnel-headers](img/04-tunnel-headers.png)`
- IaC: `terraform/50-tunnel.tf` · Docs: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/get-started/create-remote-tunnel/>

## 5. Configure the SSO IdP
1. Dashboard → **Zero Trust → Settings → Authentication → Login methods → Add new**.
2. Add **Google**: paste the OAuth client ID + secret from the Google app;
   Save + **Test**.
3. Confirm **One-time PIN** is present (default). ✔ step 5.
- `![05-idps](img/05-idps.png)` · `![05-login](img/05-login.png)`
- IaC: `terraform/20-identity.tf` · Docs: <https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/google/>

## 6. Lock down `/secure`
1. Dashboard → **Zero Trust → Access → Applications → Add an application →
   Self-hosted**.
2. Application domain: subdomain `tunnel`, domain `<zone>`, **path** `secure`.
3. Identity providers: Google + One-time PIN.
4. **Policies → Add a policy** → Action *Allow* → Include:
   - *Emails* → your email
   - *Emails ending in* → `@cloudflare.com`
   - *Access groups / list* → the attendee list (create under **Access → Lists**)
5. Save. Prevent bypass: lock the Azure origin to Cloudflare IPs
   (`ORIGIN-AZURE.md`); the tunnel origin has no public IP already. ✔ step 6.
- `![06-access-policy](img/06-access-policy.png)` · `![06-allowed](img/06-allowed.png)` · `![06-denied](img/06-denied.png)` · `![06-bypass-blocked](img/06-bypass-blocked.png)`
- IaC: `terraform/40-access-secure.tf`, `30-access-lists.tf`, `70-origin-security.tf` · Docs: <https://developers.cloudflare.com/cloudflare-one/policies/access/>

## 7. The Worker
1. Locally: `cd secure-worker && npm install`.
2. Upload flags to the private R2 bucket: `../scripts/upload-flags.sh gb us ie fr de`.
3. Deploy with Wrangler: `npm run deploy` (publishes the script + the
   `tunnel.<zone>/secure*` route + the R2 binding).
4. In a browser, sign in through Access and open `https://tunnel.<zone>/secure`:
   - HTML body: `you@… authenticated at <ts> from GB`, with **GB** a link.
   - Click it → `https://tunnel.<zone>/secure/GB` renders the flag. ✔ step 7.
5. Confirm the R2 bucket has **no public access** (R2 → bucket → Settings). ✔ 7d.
- `![07-secure-identity](img/07-secure-identity.png)` · `![07-flag](img/07-flag.png)` · `![07-r2-private](img/07-r2-private.png)`
- IaC/code: `secure-worker/` · Docs: <https://developers.cloudflare.com/workers/wrangler/commands/#deploy>

---

## Live allow-list edit (the crowd-pleaser)
During the session, add an attendee and show instant access:
```bash
./scripts/add-attendee.sh someone@theircompany.com
```
They reload `/secure` and are now allowed — no redeploy.
- IaC/script: `scripts/add-attendee.sh` · Docs: <https://developers.cloudflare.com/cloudflare-one/policies/access/lists/>
