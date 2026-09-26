# Origin A — Azure App Service httpbin (assignment steps 1–3)

This is the **public, proxied** origin used to demonstrate proxying through
Cloudflare and **Full (Strict)** TLS with a **non-Cloudflare** certificate.

## What's running
httpbin runs as a container on **Azure App Service** (free tier). httpbin's
`/headers` endpoint returns all HTTP request headers in the response body,
which is exactly what step 1 asks for. Existing instances:

- `trick-httpbin-demo-uk-south.azurewebsites.net`
- `trick-httpbin-demo-east-us.azurewebsites.net`
- `trick-httpbin-demo-australia-southeast.azurewebsites.net`

> Hosting a container on an App Service Plan (incl. the platform-provided
> `*.azurewebsites.net` TLS certificate) is standard Azure and out of scope to
> re-document here:
> <https://learn.microsoft.com/azure/app-service/quickstart-custom-container> ·
> <https://learn.microsoft.com/azure/app-service/configure-ssl-certificate>

## Step 1 — endpoint that returns request headers
`GET https://<hostname>/headers` → JSON body of all request headers. No build
needed; httpbin provides it. (`kennethreitz/httpbin` / `mccutchen/go-httpbin`.)

## Step 2 — proxy through Cloudflare
Terraform creates a **proxied** CNAME `httpbin.<zone>` → the Azure hostname
(`terraform/10-dns.tf`). Orange cloud = traffic flows through Cloudflare.
- Docs: <https://developers.cloudflare.com/dns/proxy-status/>

## Step 3 — Full (Strict) with a non-Cloudflare cert
Terraform sets the zone SSL mode to **Full (Strict)** (`terraform/00-zone.tf`,
`ssl = "strict"`). In this mode Cloudflare validates the certificate the origin
presents, so the origin must serve a **publicly-trusted** cert for the hostname
Cloudflare requests. The Azure-issued cert is publicly trusted and
**not** provisioned by Cloudflare, which satisfies the requirement.

**The one thing to get right — SNI/host match.** When Cloudflare proxies
`httpbin.<zone>`, it connects to the origin using `httpbin.<zone>` as the SNI by
default. Azure must present a cert valid for that name. Two supported ways:

1. **Recommended — App Service custom domain + free managed cert.**
   In Azure: App Service → *Custom domains* → add `httpbin.<zone>` (validate via
   the TXT/CNAME Azure asks for) → *Create App Service Managed Certificate* →
   bind it. Azure now presents a valid cert for `httpbin.<zone>` and Full
   (Strict) validates cleanly.
   - <https://learn.microsoft.com/azure/app-service/app-service-web-tutorial-custom-domain>
   - <https://learn.microsoft.com/azure/app-service/configure-ssl-app-service-certificate>

2. **Alternative — origin SNI override.** Keep the DNS target as the
   `*.azurewebsites.net` name and use a Cloudflare Origin Rule to override the
   *Host* + *SNI* to the `azurewebsites.net` hostname, so the platform cert
   matches. (Origin Rules; check plan availability.)
   - <https://developers.cloudflare.com/rules/origin-rules/features/#host-header>

### Verify
```bash
# Edge serves over TLS and returns headers:
curl -sS https://httpbin.<zone>/headers | jq .

# Origin cert is Azure-issued (NOT Cloudflare), proving "non-Cloudflare cert":
echo | openssl s_client -connect <hostname>:443 -servername httpbin.<zone> 2>/dev/null \
  | openssl x509 -noout -issuer -subject
# Expect issuer = Microsoft/DigiCert (Azure), not "Cloudflare Origin CA".
```
Confirm the SSL/TLS mode shows **Full (strict)** in *SSL/TLS → Overview*.
- <https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/>

## Step 6 (part) — nobody can bypass Cloudflare
Lock the origin so only Cloudflare can reach it:

1. **Azure Access Restrictions → allow only Cloudflare IP ranges**
   (`https://www.cloudflare.com/ips-v4`, `.../ips-v6`), deny all else. This is
   the primary control.
   - <https://learn.microsoft.com/azure/app-service/app-service-ip-restrictions>
2. **(Optional) Authenticated Origin Pulls** — set
   `authenticated_origin_pulls_enabled = true` so Cloudflare presents a client
   certificate, then configure App Service to require/validate it (mTLS). This
   is defence-in-depth on top of the IP allow-list.
   - <https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/>
   - <https://learn.microsoft.com/azure/app-service/app-service-web-configure-tls-mutual-auth>

### Verify the lock
```bash
# Direct to the Azure hostname (bypassing Cloudflare) should now fail/deny:
curl -sS -o /dev/null -w "%{http_code}\n" https://<hostname>/headers   # expect 403 or timeout
# Through Cloudflare still works:
curl -sS -o /dev/null -w "%{http_code}\n" https://httpbin.<zone>/headers # expect 200
```

## Screenshots to capture for the report
- [ ] Azure custom domain + managed cert bound to `httpbin.<zone>`
- [ ] Cloudflare SSL/TLS Overview = Full (strict)
- [ ] `curl https://httpbin.<zone>/headers` output (shows `Cf-*` headers added)
- [ ] `openssl s_client` issuer = Azure/Microsoft (non-Cloudflare)
- [ ] Azure Access Restrictions list of Cloudflare IPs
- [ ] Direct-to-origin request blocked (403/timeout)
