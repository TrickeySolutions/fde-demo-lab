# IaC vs ClickOps — and how to split the tools

The assignment can be completed entirely in the dashboard (ClickOps). This repo
does it as **infrastructure-as-code** as well, because that is how a Forward
Deployed Engineer would hand a customer something repeatable, reviewable, and
tearable-down. This page explains the tool choices and where each one is the
right answer.

## The three tools (and the "CLI" question)

There is **no single general-purpose "Cloudflare CLI"** for platform
configuration. The pieces are:

| Tool | What it is | Best for |
| --- | --- | --- |
| **Terraform / OpenTofu** (`cloudflare/cloudflare` v5 provider) | Declarative IaC over the Cloudflare API | Zones, DNS, SSL/TLS, Access (Zero Trust), Tunnels, R2 buckets, WAF, rulesets — the durable platform config |
| **Wrangler** | The Workers CLI | Worker code lifecycle: `dev`, `deploy`, routes + bindings (via `wrangler.jsonc`), `tail`, R2 object put/get, secrets |
| **`cloudflared`** | The Tunnel connector daemon | Runs on the origin host to dial out and serve the tunnel |
| REST API / `curl` | The lowest layer both of the above call | One-off imperative actions with no resource to track (e.g. live `add-attendee.sh` list append) |
| `cf-terraforming` | Cloudflare's importer | Generating Terraform + state from config already made in the dashboard |

> OpenTofu is used here (the open-source Terraform fork); the config is
> identical for HashiCorp Terraform ≥ 1.6. Commands below use `tofu`.

## The split used in this repo

```
Terraform (terraform/)                     Wrangler (secure-worker/)
├── zone settings (Full-Strict TLS)        ├── Worker code (src/index.ts)
├── DNS records (httpbin, tunnel)          ├── Worker route (tunnel.<zone>/secure*)
├── Zero Trust: IdP, lists, apps, policies ├── R2 binding (FLAGS)
├── Cloudflare Tunnel + ingress config     └── R2 object uploads (flags)
├── R2 bucket (the resource)                   (scripts/upload-flags.sh)
└── Authenticated Origin Pulls
```

### Why this line?
- **Single writer per resource.** The #1 way to get a `409 Conflict` or drift is
  to let Terraform *and* Wrangler both manage the same Worker script or route.
  The Worker code, its route and its bindings change together on every deploy,
  so Wrangler owns them as one unit. Everything around the Worker changes on a
  different cadence, so Terraform owns that.
- **R2 is split deliberately.** The *bucket* is infrastructure → Terraform. The
  *objects* (flag SVGs) are data → Wrangler (`r2 object put`). Terraform should
  not carry blobs in state.
- **The tunnel config is code, not a `config.yml`.** Using `config_src =
  "cloudflare"` puts the ingress rules in Terraform (remotely-managed tunnel),
  so the only thing on the VM is the connector + token — nothing to drift.
- **Live edits use the API directly.** Adding an attendee mid-meeting is an
  imperative one-shot, so `add-attendee.sh` PATCHes the list via the API and we
  reconcile back into Terraform afterwards. Doing it through `tofu apply` live
  would be slow and risky.

## Could the Worker be done in Terraform instead?
Yes — the v5 provider has `cloudflare_workers_script` + `cloudflare_workers_route`.
`terraform/80-worker-route.tf` keeps that alternative as a commented block. It
is a reasonable choice for a CI/CD pipeline that builds the bundle and applies
everything together. For a hand-driven demo, Wrangler is faster to iterate and
gives `wrangler tail` for live logs, so we keep the Worker on Wrangler.

## What must stay ClickOps
Some things have no API and are genuinely manual (documented in
`PREREQUISITES.md`): creating the account, activating the zone (NS change),
enabling Zero Trust / R2, and creating the Google OAuth app. An honest IaC story
names these rather than pretending to automate them.

## Docs
- Terraform provider: <https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs>
- Wrangler: <https://developers.cloudflare.com/workers/wrangler/>
- Tunnel (remotely-managed): <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/remote-tunnel-permissions/>
- cf-terraforming: <https://developers.cloudflare.com/terraform/advanced-topics/import-cloudflare-resources/>
