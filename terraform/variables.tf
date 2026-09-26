# ---------------------------------------------------------------------------
# Inputs. Real values go in terraform.tfvars (gitignored) or TF_VAR_* env vars.
# Secrets (API token, Google OAuth client secret) must ONLY be passed via env
# vars (TF_VAR_cloudflare_api_token, TF_VAR_google_client_secret) — never
# committed.
# ---------------------------------------------------------------------------

variable "cloudflare_api_token" {
  description = "Cloudflare API token. Pass via TF_VAR_cloudflare_api_token; never commit."
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID for the FDE demo account."
  type        = string
}

# --- Zone -------------------------------------------------------------------

variable "zone_name" {
  description = "Apex DNS zone added to the free account (full setup). All demo hostnames sit under it."
  type        = string
  default     = "fde-demo.trickey.solutions"
}

variable "zone_enabled" {
  description = <<-EOT
    Gate for zone-dependent resources (zone settings, DNS records, Worker route,
    Authenticated Origin Pulls). Leave false for the first, account-only apply
    (IdP, lists, R2, Tunnel, Access apps) before the zone is delegated and
    active; flip to true once `dig NS <zone_name>` returns the account's
    Cloudflare nameservers and the zone shows Active in the dashboard.
  EOT
  type        = bool
  default     = false
}

# --- Zero Trust org ---------------------------------------------------------

variable "team_name" {
  description = "Zero Trust team name (the <team>.cloudflareaccess.com auth domain). Set when you enable Zero Trust in the dashboard; must match here."
  type        = string
  default     = "fde-demo"
}

variable "team_display_name" {
  description = "Friendly organisation name shown on the Access sign-in page."
  type        = string
  default     = "FDE Demo"
}

# --- Hostnames --------------------------------------------------------------

variable "httpbin_hostname" {
  description = "Hostname proxied to the public Azure httpbin origin (steps 1-3: proxy + Full-Strict TLS)."
  type        = string
  default     = "httpbin.fde-demo.trickey.solutions"
}

variable "tunnel_hostname" {
  description = "Hostname served through Cloudflare Tunnel from the local VM origin (step 4). Also carries the /secure Worker + Access (steps 6-7)."
  type        = string
  default     = "tunnel.fde-demo.trickey.solutions"
}

variable "tunnel_service" {
  description = "Local service cloudflared forwards the tunnel hostname to, on the VM. Default 8080 so httpbin can run without admin/root (port 80 would need elevation)."
  type        = string
  default     = "http://localhost:8080"
}

variable "deck_hostname" {
  description = "Hostname the presentation deck Worker is served on (fde-demo-deck)."
  type        = string
  default     = "deck.fde-demo.trickey.solutions"
}

variable "secure_path" {
  description = "Path locked down by Access and served by the identity Worker (assignment step 6/7)."
  type        = string
  default     = "/secure"
}

# --- Origin (Azure App Service httpbin) -------------------------------------

variable "azure_origin_hostname" {
  description = "Public Azure App Service hostname the httpbin record proxies to (presents the non-Cloudflare *.azurewebsites.net cert for Full-Strict). CNAME target."
  type        = string
  default     = "trick-httpbin-demo-uk-south.azurewebsites.net"
}

variable "authenticated_origin_pulls_enabled" {
  description = "Enable zone-wide Authenticated Origin Pulls (mTLS from Cloudflare to origin). Effective only if the origin is configured to require Cloudflare's client cert; see docs/ORIGIN-AZURE.md. Primary non-bypass control is the Azure IP allow-list."
  type        = bool
  default     = false
}

# --- Access allow-list ------------------------------------------------------

variable "self_email" {
  description = "Your own email — always allowed to reach the /secure path (assignment step 6)."
  type        = string
}

variable "cloudflare_email_domain" {
  description = "Email domain allowed to reach /secure alongside you (assignment step 6)."
  type        = string
  default     = "cloudflare.com"
}

variable "attendee_emails" {
  description = "Extra attendee emails allowed live during the demo. Often empty at apply; added live via scripts/add-attendee.sh, then reconciled here."
  type        = list(string)
  default     = []
}

# --- Google SSO IdP (assignment step 5) -------------------------------------

variable "google_idp_enabled" {
  description = "Create the Google OAuth SSO identity provider. Requires google_client_id + TF_VAR_google_client_secret from a Google Cloud OAuth app. One-time PIN is always created as a fallback."
  type        = bool
  default     = false
}

variable "google_client_id" {
  description = "Google OAuth client ID (from Google Cloud Console). Not secret, but pair with the secret env var."
  type        = string
  default     = ""
}

variable "google_client_secret" {
  description = "Google OAuth client secret. Pass via TF_VAR_google_client_secret; never commit."
  type        = string
  default     = ""
  sensitive   = true
}

# --- R2 ---------------------------------------------------------------------

variable "flags_bucket_name" {
  description = "Name of the private R2 bucket holding country flag SVGs (assignment step 7d)."
  type        = string
  default     = "fde-demo-flags"
}

variable "r2_location" {
  description = "R2 bucket location hint (UPPERCASE: WNAM, ENAM, WEUR, EEUR, APAC)."
  type        = string
  default     = "WEUR"
}
