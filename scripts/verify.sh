#!/usr/bin/env bash
# verify.sh — post-deploy acceptance test for the FDE demo environment.
#
# The demo deck is itself a Cloudflare Worker that independently interrogates
# the deployed environment and proves each assignment requirement. This script
# calls its aggregate endpoint (/api/checks/run), prints a table, and exits
# non-zero if any check hard-fails — so it doubles as a CI/CD gate to run after
# `tofu apply` / `wrangler deploy`.
#
# Usage:
#   ./scripts/verify.sh
#   BASE_URL=https://deck.fde-demo.trickey.solutions ./scripts/verify.sh
#
# Requires: curl, jq.
set -euo pipefail

BASE_URL="${BASE_URL:-https://deck.fde-demo.trickey.solutions}"
ENDPOINT="${BASE_URL%/}/api/checks/run"

command -v jq >/dev/null 2>&1 || { echo "jq is required (brew install jq)"; exit 2; }

echo "→ Validating deployment via ${ENDPOINT}"
RESP="$(curl -fsS "$ENDPOINT")" || { echo "❌ could not reach ${ENDPOINT}"; exit 2; }

echo "$RESP" | jq -r '
  .results[]
  | "  " + ({pass:"✅",warn:"⚠️ ",fail:"❌",skip:"⏭️ "}[.status] // "? ")
    + " [" + .pillar + "] " + .title + " — " + .detail'

echo
echo "$RESP" | jq -r '"Summary: \(.summary.passed) passed · \(.summary.warned) warned · \(.summary.skipped) skipped · \(.summary.failed) failed (of \(.summary.total))"'

if [ "$(echo "$RESP" | jq -r '.ok')" = "true" ]; then
  echo "✅ deployment validated"
  exit 0
fi
echo "❌ one or more checks failed"
exit 1
