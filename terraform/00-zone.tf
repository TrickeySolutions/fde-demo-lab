# ---------------------------------------------------------------------------
# Zone lookup + edge TLS settings (assignment steps 2 & 3).
#
# The zone itself is added to the account and activated in the dashboard (NS
# change at the parent) — see docs/PREREQUISITES.md. Terraform only looks it up
# by name and manages its settings, so it never tries to create/destroy the
# zone. Everything here is gated on var.zone_enabled so the first apply can run
# account-only, before the zone is active.
#
# ssl = "strict" is Full (Strict): Cloudflare validates the origin certificate.
# The Azure origin presents a publicly-trusted (non-Cloudflare) cert, satisfying
# "at least Full-Strict with a non-Cloudflare provisioned TLS certificate".
# Docs: https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/full-strict/
# ---------------------------------------------------------------------------

data "cloudflare_zone" "this" {
  count  = var.zone_enabled ? 1 : 0
  filter = { name = var.zone_name }
}

locals {
  zone_id = var.zone_enabled ? data.cloudflare_zone.this[0].zone_id : ""
}

# Full (Strict) encryption between Cloudflare and the origin.
# https://developers.cloudflare.com/api/resources/zones/subresources/settings/
resource "cloudflare_zone_setting" "ssl" {
  count      = var.zone_enabled ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "ssl"
  value      = "strict"
}

# Redirect all visitor HTTP to HTTPS at the edge.
resource "cloudflare_zone_setting" "always_use_https" {
  count      = var.zone_enabled ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "always_use_https"
  value      = "on"
}

# Reject legacy TLS at the edge.
resource "cloudflare_zone_setting" "min_tls_version" {
  count      = var.zone_enabled ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "min_tls_version"
  value      = "1.2"
}

resource "cloudflare_zone_setting" "tls_1_3" {
  count      = var.zone_enabled ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "tls_1_3"
  value      = "on"
}

resource "cloudflare_zone_setting" "automatic_https_rewrites" {
  count      = var.zone_enabled ? 1 : 0
  zone_id    = local.zone_id
  setting_id = "automatic_https_rewrites"
  value      = "on"
}
