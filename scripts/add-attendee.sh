#!/usr/bin/env bash
# Add an attendee email to the Access allow-list — live, during the meeting.
# The append takes effect immediately, so the person can reach the protected
# /secure path and deck /admin right away.
#
# Usage:  scripts/add-attendee.sh person@example.com [another@example.com ...]
#
# Requires:
#   export CLOUDFLARE_API_TOKEN="<token with Zero Trust edit>"
#   export CLOUDFLARE_ACCOUNT_ID="<account id>"
#
# NOTE: this appends directly via the API. To keep Terraform state tidy, add the
# same emails to attendee_emails in terraform.tfvars afterwards and re-apply.
set -euo pipefail
cd "$(dirname "$0")/../terraform"

: "${CLOUDFLARE_API_TOKEN:?set CLOUDFLARE_API_TOKEN}"
: "${CLOUDFLARE_ACCOUNT_ID:?set CLOUDFLARE_ACCOUNT_ID}"
[[ $# -ge 1 ]] || { echo "usage: $0 email [email ...]"; exit 1; }

TF=$(command -v tofu || command -v terraform)
LIST_ID=$("$TF" output -raw attendees_list_id)

APPEND=$(printf '{"value":"%s"},' "$@" | sed 's/,$//')
BODY="{\"append\":[${APPEND}]}"

curl -fsS --request PATCH \
  "https://api.cloudflare.com/client/v4/accounts/${CLOUDFLARE_ACCOUNT_ID}/gateway/lists/${LIST_ID}" \
  --header "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  --header "Content-Type: application/json" \
  --data "${BODY}" >/dev/null

echo "Added to attendee list: $*"
echo "(Remember to add these to attendee_emails in terraform.tfvars and re-apply to reconcile state.)"
