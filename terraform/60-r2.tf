# ---------------------------------------------------------------------------
# Private R2 bucket for country flag assets (assignment step 7d).
#
# Terraform creates the (private) bucket only. Public r2.dev access is left
# disabled, so the flags are reachable solely through the Worker's binding —
# which is the point of "stored in a private R2 bucket". The flag objects
# themselves are uploaded with Wrangler (scripts/upload-flags.sh) because
# object contents are a data-plane concern, not infrastructure.
#
# https://developers.cloudflare.com/r2/buckets/
# ---------------------------------------------------------------------------

resource "cloudflare_r2_bucket" "flags" {
  account_id = var.cloudflare_account_id
  name       = var.flags_bucket_name
  location   = var.r2_location
}
