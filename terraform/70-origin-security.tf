# ---------------------------------------------------------------------------
# Non-bypass controls for the PUBLIC Azure origin (assignment step 6:
# "Ensure nobody can bypass Cloudflare and access your server's IP directly").
#
# For the Tunnel origin this is automatic — there is no public inbound at all.
# For the Azure App Service origin there are two layers:
#
#   1. PRIMARY (required): Azure App Service Access Restrictions allowing only
#      Cloudflare's published IP ranges (https://www.cloudflare.com/ips/).
#      Configured on the Azure side; there is no Cloudflare resource for it.
#
#   2. DEFENCE-IN-DEPTH (optional): zone-wide Authenticated Origin Pulls, so
#      Cloudflare presents a client certificate the origin can require (mTLS).
#      Only effective once the origin is configured to validate Cloudflare's
#      client cert — see the docs. Toggle with authenticated_origin_pulls_enabled.
#
# https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/
# ---------------------------------------------------------------------------

resource "cloudflare_authenticated_origin_pulls_settings" "zone" {
  count   = var.zone_enabled && var.authenticated_origin_pulls_enabled ? 1 : 0
  zone_id = local.zone_id
  enabled = true
}
