# ---------------------------------------------------------------------------
# Zero Trust Access over the deck's /admin path (demonstration flourish).
#
# The presentation deck (fde-demo-deck) is public, but deck.<zone>/admin is
# gated by Access using the same live-editable attendee list. This lets you
# add an audience member's email live in the meeting and have them reach an
# attendee-only page — a clean, low-risk way to show ZTNA end to end without
# touching the assignment's /secure app.
# ---------------------------------------------------------------------------

resource "cloudflare_zero_trust_access_policy" "deck_admin_allow" {
  account_id = var.cloudflare_account_id
  name       = "Allow self and attendees (deck admin)"
  decision   = "allow"

  include = [
    { email = { email = var.self_email } },
    { email_domain = { domain = var.cloudflare_email_domain } },
    { email_list = { id = cloudflare_zero_trust_list.attendees.id } },
  ]
}

resource "cloudflare_zero_trust_access_application" "deck_admin" {
  account_id                = var.cloudflare_account_id
  name                      = "FDE Demo — deck /admin"
  domain                    = "${var.deck_hostname}/admin"
  type                      = "self_hosted"
  session_duration          = "24h"
  app_launcher_visible      = false
  auto_redirect_to_identity = false
  allowed_idps              = local.access_idp_ids

  policies = [
    { id = cloudflare_zero_trust_access_policy.deck_admin_allow.id, precedence = 1 },
  ]
}
