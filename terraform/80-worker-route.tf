# ---------------------------------------------------------------------------
# Worker route for the /secure identity Worker (assignment step 7).
#
# DECISION: the route is defined in secure-worker/wrangler.jsonc and owned by
# Wrangler, co-located with the Worker code it points at. That keeps a single
# writer per resource (see docs/IAC-VS-CLICKOPS.md) and means `wrangler deploy`
# publishes the script and its route together.
#
# The block below is the Terraform-managed ALTERNATIVE, kept commented so the
# choice is explicit and easy to flip. If you enable it, remove the `routes`
# entry from wrangler.jsonc so the two do not fight over the same route.
#
#   pattern     = "tunnel.<zone>/secure*"
#   script      = "<name of the deployed Worker>"  (fde-demo-secure)
#
# https://developers.cloudflare.com/workers/configuration/routing/routes/
# ---------------------------------------------------------------------------

# resource "cloudflare_workers_route" "secure" {
#   count       = var.zone_enabled ? 1 : 0
#   zone_id     = local.zone_id
#   pattern     = "${var.tunnel_hostname}${var.secure_path}*"
#   script      = "fde-demo-secure"
# }
