#!/usr/bin/env bash
# Bring up (or update) the FDE demo account configuration with OpenTofu.
#
# Prerequisites (see docs/PREREQUISITES.md):
#   - tofu (OpenTofu) or terraform installed
#   - export TF_VAR_cloudflare_api_token="<scoped API token>"
#   - export TF_VAR_google_client_secret="..."   # only if google_idp_enabled = true
#   - terraform/terraform.tfvars filled in (copy from terraform.tfvars.example)
#
# State is local (terraform/terraform.tfstate) and gitignored.
set -euo pipefail
cd "$(dirname "$0")/../terraform"

TF=$(command -v tofu || command -v terraform)
echo "Using: $TF"

"$TF" init -input=false
"$TF" fmt
"$TF" validate
"$TF" plan -out tfplan
echo
echo "Review the plan above. To apply, run:  (cd terraform && $TF apply tfplan)"
