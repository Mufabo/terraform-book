# Outputs expose where the secrets are, never what they contain.
output "secret_ids" {
  value = {
    partner_token = google_secret_manager_secret.partner_token.secret_id
    signing_key   = google_secret_manager_secret.signing_key.secret_id
  }
}

output "app_service_account" {
  value = google_service_account.app.email
}
