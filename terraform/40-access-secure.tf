# ---------------------------------------------------------------------------
# Zero Trust Access over the /secure path (assignment steps 6 & 7).
#
# A path-scoped self-hosted Access application on tunnel.<zone>/secure. Only
# three groups get in: you (self_email), anyone @cloudflare.com, and any live
# attendee on the list. Everyone else is denied. Because /secure is fronted by
# the Tunnel (no public origin IP) and Access, the origin cannot be reached
# directly — satisfying "nobody can bypass Cloudflare".
#
# The identity Worker (secure-worker/) is served on this same path via a Worker
# route, so Access authenticates the request before the Worker runs and injects
# the Cf-Access-Authenticated-User-Email header the Worker reads.
#
# NOTE: if the zone is still activating when this is first created, re-save
# (re-apply) once the zone is Active. https://developers.cloudflare.com/dns/zone-setups/subdomain-setup/#access
# ---------------------------------------------------------------------------

locals {
  # IdPs offered on the Access login screen: OTP always, Google when enabled.
  access_idp_ids = concat(
    [cloudflare_zero_trust_access_identity_provider.otp.id],
    var.google_idp_enabled ? [cloudflare_zero_trust_access_identity_provider.google[0].id] : [],
  )
}

resource "cloudflare_zero_trust_access_policy" "secure_allow" {
  account_id = var.cloudflare_account_id
  name       = "Allow self, Cloudflare and attendees"
  decision   = "allow"

  include = [
    { email = { email = var.self_email } },
    { email_domain = { domain = var.cloudflare_email_domain } },
    { email_list = { id = cloudflare_zero_trust_list.attendees.id } },
  ]
}

resource "cloudflare_zero_trust_access_application" "secure" {
  account_id                = var.cloudflare_account_id
  name                      = "FDE Demo — /secure identity"
  domain                    = "${var.tunnel_hostname}${var.secure_path}"
  type                      = "self_hosted"
  session_duration          = "24h"
  app_launcher_visible      = false
  auto_redirect_to_identity = false
  allowed_idps              = local.access_idp_ids

  policies = [
    { id = cloudflare_zero_trust_access_policy.secure_allow.id, precedence = 1 },
  ]
}
