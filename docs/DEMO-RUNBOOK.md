# Demo runbook — presenting to the panel

A tight ~15-minute live flow. `<zone> = fde-demo.trickey.solutions`.

## Before the meeting
- [ ] `zone_enabled = true` applied; `tofu plan` is clean (no drift).
- [ ] Tunnel **Healthy** (VM on, `cloudflared` running, Docker httpbin up).
- [ ] Azure httpbin reachable via `httpbin.<zone>/headers`; origin locked to CF.
- [ ] Flags uploaded; `secure-worker` deployed; `wrangler tail` ready in a pane.
- [ ] Deck (`fde-demo-deck`) open; two browsers ready: one signed in as you, one
      private/incognito for the "denied" and "add live" moments.
- [ ] `add-attendee.sh` ready in a terminal with `CLOUDFLARE_API_TOKEN` +
      `CLOUDFLARE_ACCOUNT_ID` exported.

## Flow

1. **Framing (deck, 2 min).** The connectivity-cloud story: connect any origin,
   secure with identity, run logic at the edge. Show the architecture slide.

2. **Origin + proxy + Full-Strict (3 min).**
   - `curl -sS https://httpbin.<zone>/headers | jq '.headers | keys'` — headers
     returned; point out the `Cf-*` headers Cloudflare added.
   - SSL/TLS Overview = **Full (strict)**; `openssl s_client` issuer = Azure →
     "encrypted to origin, validated, with a non-Cloudflare cert".
   - `curl` the raw Azure hostname → blocked → "nobody bypasses Cloudflare".

3. **Tunnel (2 min).** Zero Trust → Networks → Tunnels: `fde-demo-tunnel`
   Healthy. `curl https://tunnel.<zone>/headers` → served from a laptop VM with
   no public IP, no open ports.

4. **Access + identity (3 min).**
   - Incognito → `https://tunnel.<zone>/secure` → Access login (Google + OTP).
   - Signed in as you → the Worker's identity line renders.
   - Incognito as a non-listed user → **denied**.

5. **Live allow-list (2 min).** Ask an audience member for their email:
   ```bash
   ./scripts/add-attendee.sh their.email@company.com
   ```
   They hit `/secure` and are in — no redeploy. (Same list also gates
   `deck.<zone>/admin`.)

6. **Worker + R2 (2 min).** On `/secure`, click the **country** link →
   `/secure/<CC>` renders the flag, streamed from the **private** R2 bucket
   (show the bucket has no public access). Glance at `wrangler tail`.

7. **The FDE point (1 min).** Flip to the repo: this whole account is
   `tofu apply` + `wrangler deploy`, reviewable in PRs, tearable down — and the
   few genuinely-manual steps are named honestly in `PREREQUISITES.md`.

## Recovery / gotchas
- `/secure` shows httpbin, not the Worker → the Worker route didn't win; confirm
  `wrangler deployments list` and the route pattern matches the hostname.
- Access loops or 500 on a freshly-active zone → re-apply so the Access app
  re-saves against the now-active zone.
- Flag 404 → the code isn't uploaded; `./scripts/upload-flags.sh <cc>`.
- Tunnel Down → restart `cloudflared` on the VM; check Docker httpbin on :80.
- Full-Strict 526 → origin cert doesn't match `httpbin.<zone>`; fix the Azure
  custom-domain cert / SNI override (`ORIGIN-AZURE.md`).

## Teardown
```bash
cd secure-worker && npx wrangler delete           # remove the Worker + route
cd ../terraform && tofu destroy                    # remove account/zone config
# Stop cloudflared + Docker on the VM. Optionally remove the zone + account.
```
