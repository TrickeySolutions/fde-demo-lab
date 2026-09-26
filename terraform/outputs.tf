output "zone_name" {
  description = "The apex zone all demo hostnames sit under."
  value       = var.zone_name
}

output "team_login_domain" {
  description = "Zero Trust auth domain (where users authenticate)."
  value       = "${var.team_name}.cloudflareaccess.com"
}

output "secure_url" {
  description = "Access-protected identity Worker URL (assignment steps 6-7)."
  value       = "https://${var.tunnel_hostname}${var.secure_path}"
}

output "httpbin_url" {
  description = "Proxied httpbin origin URL (assignment steps 1-3). Try /headers."
  value       = "https://${var.httpbin_hostname}/headers"
}

output "deck_url" {
  description = "Presentation deck URL (fde-demo-deck)."
  value       = "https://${var.deck_hostname}"
}

output "tunnel_id" {
  description = "Cloudflare Tunnel ID (for the DNS CNAME and connector)."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "tunnel_token" {
  description = "Connector token to run cloudflared on the VM. Fetch with: tofu output -raw tunnel_token"
  value       = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
  sensitive   = true
}

output "attendees_list_id" {
  description = "Zero Trust list ID used by scripts/add-attendee.sh."
  value       = cloudflare_zero_trust_list.attendees.id
}

output "flags_bucket" {
  description = "Private R2 bucket name for country flags."
  value       = cloudflare_r2_bucket.flags.name
}
