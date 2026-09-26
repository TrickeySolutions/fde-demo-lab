# ---------------------------------------------------------------------------
# Attendee allow-list (assignment step 6).
#
# Modelled as a Zero Trust email list so it can be edited live in the meeting:
# scripts/add-attendee.sh appends an email via the API and the person gains
# access immediately, without a re-apply. Reconcile back into var.attendee_emails
# afterwards to keep state tidy.
#
# https://developers.cloudflare.com/cloudflare-one/policies/access/lists/
# ---------------------------------------------------------------------------

resource "cloudflare_zero_trust_list" "attendees" {
  account_id  = var.cloudflare_account_id
  name        = "fde_demo_attendees"
  description = "Attendees allowed to reach the Access-protected /secure path and deck /admin. Often populated live during the demo."
  type        = "EMAIL"
  items       = [for e in var.attendee_emails : { value = e }]
}
