# AGENTS.md — fde-demo-lab

Guidance for any agent (or engineer) iterating on this repository.

## What this repo is
Infrastructure-as-code and a Worker that together answer the Cloudflare FDE
"Application Services" take-home assignment as a **real, deployed environment**:
httpbin proxied through Cloudflare with Full-Strict TLS, a Cloudflare Tunnel, a
Zero Trust Access policy, and a Worker returning authenticated identity plus a
country flag from a private R2 bucket. The written report and click-by-click
dashboard walkthrough live in `docs/`.

This repo is intended to be **public** (the assignment requires the Worker code
in a public git repo), so treat it accordingly.

## Hard rules
1. **No secrets in git.** The Cloudflare API token, Google OAuth client secret,
   and the Tunnel connector token are supplied at runtime via environment
   variables or the gitignored `terraform.tfvars` — never committed. The
   account ID and public hostnames are not secrets and may appear in code.
2. **Everything reproducible from code.** If you configure something in the
   dashboard during a session, fold it back into Terraform/Wrangler afterwards,
   or record it in `docs/CLICKOPS.md` as a deliberate manual step.
3. **Single writer per resource.** Terraform owns platform config; Wrangler owns
   the Worker (code, route, bindings). Never manage the same resource in both.

## Mandatory dashboard steps (cannot be done by this code)
See `docs/PREREQUISITES.md`. In short: create the free account, add + activate
the apex zone (NS change), enable Zero Trust (team name must match
`var.team_name`), enable R2, and create the Google OAuth app (if using Google
SSO). Flag these to the operator rather than inventing Terraform for them.

## Conventions
- Provider: `cloudflare/cloudflare` v5. Pin in `terraform/versions.tf`.
- Terraform files are numbered by concern (`00-` zone … `80-` worker route).
- v5 uses HCL **object/attribute** assignment for nested settings, e.g.
  `include = [{ email = { email = "…" } }]`, `config = { ingress = [ … ] }` —
  not legacy `{ }` blocks. Verify shapes against the provider schema
  (`tofu providers schema -json`) before guessing.
- Zone-dependent resources (`00-zone`, `10-dns`, `70-origin-security`, the
  commented route in `80-`) are gated on `var.zone_enabled` so the first apply
  can run account-only before the zone is active.
- Before committing Terraform changes run: `cd terraform && tofu fmt &&
  tofu validate`. Keep validate green.
- State is **local** and gitignored. There is no remote backend.
- Every factual claim in `docs/` should link to the relevant page on
  `developers.cloudflare.com`.

## Layout
```
terraform/     account + zone configuration as code (numbered by concern)
secure-worker/ the /secure identity Worker (Wrangler; owns its route + R2 binding)
scripts/       bootstrap · add-attendee · deploy-worker · upload-flags
assets/flags/  optional vendored flag SVGs (else fetched from flagcdn.com)
docs/          written report, clickops walkthrough, requirements coverage, runbook
```

## Adding a capability
1. Add the resource(s) in the appropriately-numbered `terraform/*.tf` file with
   a short comment on the requirement it serves + a dev-docs link.
2. `tofu fmt && tofu validate`.
3. If it needs a secret, add a `variable` (sensitive) and document the env var —
   never a default value containing the secret.
4. Update `docs/REQUIREMENTS-COVERAGE.md` if it changes how a requirement is met.
