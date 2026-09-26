# ---------------------------------------------------------------------------
# DNS records (assignment steps 2 & 4).
#
# All proxied (orange cloud) so traffic goes through Cloudflare.
#   httpbin.<zone> -> public Azure App Service origin (steps 1-3)
#   tunnel.<zone>  -> Cloudflare Tunnel connector on the local VM (step 4)
#
# The deck hostname (deck.<zone>) is intentionally NOT managed here: it is
# created as a Worker custom domain by `wrangler deploy` in fde-demo-deck, so
# managing it here too would cause a conflict. Keep DNS ownership single-writer.
#
# ttl = 1 means "Auto" (required while proxied).
# https://developers.cloudflare.com/dns/manage-dns-records/how-to/create-dns-records/
# ---------------------------------------------------------------------------

resource "cloudflare_dns_record" "httpbin" {
  count   = var.zone_enabled ? 1 : 0
  zone_id = local.zone_id
  name    = var.httpbin_hostname
  type    = "CNAME"
  content = var.azure_origin_hostname
  proxied = true
  ttl     = 1
  comment = "FDE demo: httpbin origin on Azure App Service (Full-Strict TLS)."
}

resource "cloudflare_dns_record" "tunnel" {
  count   = var.zone_enabled ? 1 : 0
  zone_id = local.zone_id
  name    = var.tunnel_hostname
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "FDE demo: Cloudflare Tunnel to the local VM httpbin origin."
}
