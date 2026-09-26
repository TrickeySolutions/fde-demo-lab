# ---------------------------------------------------------------------------
# Cloudflare Tunnel (assignment step 4).
#
# A remotely-managed tunnel: the connector (cloudflared) runs on the local
# UTM VM and dials out to Cloudflare, so the origin has NO public inbound and
# cannot be bypassed. The ingress config lives here as code (config_src =
# "cloudflare") rather than a local config.yml, so the routing is reproducible.
#
# Ingress:
#   tunnel.<zone>            -> httpbin on the VM (var.tunnel_service, default :8080)
#   everything else          -> 404
#
# The origin is loopback HTTP (or self-signed HTTPS with no_tls_verify) — the
# tunnel itself provides the encryption, so a self-signed origin cert is fine
# here; Full-Strict is demonstrated separately on the Azure origin.
#
# Run the connector on the VM with the token from the output `tunnel_token`
# (see README / docs/ORIGIN-TUNNEL-VM.md).
# https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/
# ---------------------------------------------------------------------------

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.cloudflare_account_id
  name       = "fde-demo-tunnel"
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = [
      {
        hostname = var.tunnel_hostname
        service  = var.tunnel_service
        origin_request = {
          no_tls_verify = true
        }
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

# Connector token — sensitive. Fetch with:
#   tofu output -raw tunnel_token
data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}
