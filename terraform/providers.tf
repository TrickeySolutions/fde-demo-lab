# Cloudflare provider.
#
# The API token is supplied at runtime via the TF_VAR_cloudflare_api_token
# environment variable (never committed). See README.md for the required
# token scopes.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
