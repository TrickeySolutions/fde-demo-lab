#!/usr/bin/env bash
# Deploy the /secure identity Worker with Wrangler (assignment step 7i).
#
# The Worker's route (tunnel.<zone>/secure*) and its R2 binding are declared in
# secure-worker/wrangler.jsonc, so a single `wrangler deploy` publishes the
# script, wires the binding, and attaches the route. Run this AFTER:
#   - the zone is Active (zone_enabled = true applied), and
#   - flags are uploaded (scripts/upload-flags.sh).
#
# Requires:
#   export CLOUDFLARE_API_TOKEN="<token with Workers Scripts edit>"
#   export CLOUDFLARE_ACCOUNT_ID="<account id>"
set -euo pipefail
cd "$(dirname "$0")/../secure-worker"

npm install
npx wrangler deploy
echo
echo "Deployed. The Worker serves /secure and /secure/<COUNTRY> on the tunnel hostname."
