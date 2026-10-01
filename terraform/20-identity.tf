# ---------------------------------------------------------------------------
# Identity providers (assignment step 5).
#
# Two are configured:
#   1. Google OAuth  — the "real" SSO IdP. @cloudflare.com is Google Workspace,
#      so panel members with a cloudflare.com address sign in with Google.
#      Enabled when var.google_idp_enabled = true (needs a Google Cloud OAuth
#      app: client id + TF_VAR_google_client_secret). Setup: docs/PREREQUISITES.md.
#   2. One-time PIN  — always on, so any attendee email you add live can log in
#      with an emailed code without needing a Google account.
#
# Google IdP docs:
#   https://developers.cloudflare.com/cloudflare-one/identity/idp-integration/google/
# One-time PIN docs:
#   https://developers.cloudflare.com/cloudflare-one/identity/one-time-pin/
# ---------------------------------------------------------------------------

resource "cloudflare_zero_trust_access_identity_provider" "otp" {
  account_id = var.cloudflare_account_id
  name       = "One-time PIN"
  type       = "onetimepin"
  config     = {}
}

resource "cloudflare_zero_trust_access_identity_provider" "google" {
  count      = var.google_idp_enabled ? 1 : 0
  account_id = var.cloudflare_account_id
  name       = "Google"
  type       = "google"
  config = {
    client_id     = var.google_client_id
    client_secret = var.google_client_secret
  }
}
