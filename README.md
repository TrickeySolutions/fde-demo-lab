# FDE Application Services Assignment — lab (IaC + Worker)

A **real, deployed** answer to the Cloudflare Forward Deployed Engineer
"Application Services" take-home, built as **infrastructure-as-code** with a
click-by-click dashboard walkthrough as the alternative.

- **httpbin** origin proxied through Cloudflare with **Full (Strict)** TLS to a
  non-Cloudflare origin certificate (Azure App Service).
- A **Cloudflare Tunnel** from a local VM origin, with no public inbound.
- **Zero Trust Access** locking down `tunnel.<zone>/secure` to you, anyone
  `@cloudflare.com`, and a live-editable attendee list — via **Google SSO** (or
  One-time PIN).
- A **Worker** on `/secure` returning `${EMAIL} authenticated at ${TIMESTAMP}
  from ${COUNTRY}`, with `${COUNTRY}` linking to a flag served from a **private
  R2 bucket**.

> Zone default: `fde-demo.trickey.solutions`. Everything is parametrised — see
> `terraform/variables.tf`.

## Architecture

```
                         ┌─────────────────────────── Cloudflare ───────────────────────────┐
  httpbin.<zone> ──────▶ │  Proxy + Full (Strict) TLS ──────────────▶ Azure App Service httpbin
                         │                                            (*.azurewebsites.net cert)
  tunnel.<zone> ───────▶ │  DNS ▶ Tunnel  ◀──cloudflared── local UTM VM ▶ dockerised httpbin
  tunnel.<zone>/secure ▶ │  Access (Google/OTP) ▶ Worker route ▶ fde-demo-secure ▶ R2 (flags)
  deck.<zone> ─────────▶ │  fde-demo-deck Worker (public); /admin behind Access
                         └───────────────────────────────────────────────────────────────────┘
```

## What builds what

| Layer | Tool | Where |
| --- | --- | --- |
| Zone settings, DNS, Access (IdP/lists/apps/policies), Tunnel + ingress, R2 bucket, Authenticated Origin Pulls | **OpenTofu** (`cloudflare` v5) | `terraform/` |
| `/secure` identity Worker — code, route, R2 binding | **Wrangler** | `secure-worker/` |
| Tunnel connector on the VM | **cloudflared** | `docs/ORIGIN-TUNNEL-VM.md` |
| Azure httpbin origin + custom-domain cert + IP allow-list | **Azure (documented)** | `docs/ORIGIN-AZURE.md` |

See `docs/IAC-VS-CLICKOPS.md` for the reasoning and the Wrangler-vs-Terraform split.

## Quick start

1. Do the one-time dashboard prerequisites — `docs/PREREQUISITES.md`.
2. Configure and apply the account-level infra:
   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars   # fill in
   cp .envrc.example .envrc && $EDITOR .envrc && source .envrc          # secrets
   ./scripts/bootstrap.sh
   (cd terraform && tofu apply tfplan)
   ```
3. Bring the tunnel up on the VM using the connector token:
   ```bash
   (cd terraform && tofu output -raw tunnel_token)   # -> use on the VM
   ```
   Full VM steps: `docs/ORIGIN-TUNNEL-VM.md`.
4. Activate the zone (NS change), then re-apply with `zone_enabled = true` to
   create DNS + zone settings.
5. Upload flags and deploy the Worker:
   ```bash
   ./scripts/upload-flags.sh gb us ie fr de
   ./scripts/deploy-worker.sh
   ```
6. Test against `docs/REQUIREMENTS-COVERAGE.md` and rehearse with
   `docs/DEMO-RUNBOOK.md`.

## Documentation (the assignment deliverable)

| File | Purpose |
| --- | --- |
| `docs/REPORT.md` | The written report (deliverable 2a–2d) |
| `docs/CLICKOPS.md` | Step-by-step dashboard walkthrough with screenshot slots |
| `docs/REQUIREMENTS-COVERAGE.md` | Requirement-by-requirement mapping + tests |
| `docs/DEMO-RUNBOOK.md` | Live demo flow for the panel |
| `docs/IAC-VS-CLICKOPS.md` | IaC vs dashboard; Wrangler vs Terraform vs API/CLI |
| `docs/ORIGIN-AZURE.md` | Azure App Service httpbin + Full-Strict cert + IP lock |
| `docs/ORIGIN-TUNNEL-VM.md` | UTM VM: Docker httpbin + cloudflared connector |
| `docs/PREREQUISITES.md` | One-time manual steps only you can do |

## Security

No secrets are committed. The API token, Google client secret and Tunnel token
are supplied at runtime via environment variables or the gitignored
`terraform.tfvars`. State is local and gitignored. See `AGENTS.md`.
