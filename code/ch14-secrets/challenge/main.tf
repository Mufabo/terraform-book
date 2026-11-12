resource "google_project_service" "secretmanager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# --- Secret 1: a value that someone hands to Terraform --------------------

resource "google_secret_manager_secret" "partner_token" {
  secret_id = "ch14c-partner-token"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "partner_token" {
  secret                 = google_secret_manager_secret.partner_token.id
  secret_data_wo         = var.partner_token
  secret_data_wo_version = var.partner_token_version
}

# --- Secret 2: a value that Terraform generates ---------------------------

ephemeral "random_password" "signing_key" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "signing_key" {
  secret_id = "ch14c-signing-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secretmanager]
}

resource "google_secret_manager_secret_version" "signing_key" {
  secret                 = google_secret_manager_secret.signing_key.id
  secret_data_wo         = ephemeral.random_password.signing_key.result
  secret_data_wo_version = 1
}

# --- The application may read both, and nothing else ----------------------

resource "google_service_account" "app" {
  account_id   = "ch14c-app"
  display_name = "Chapter 14 challenge app"
}

resource "google_secret_manager_secret_iam_member" "app_reads" {
  for_each = {
    partner_token = google_secret_manager_secret.partner_token.id
    signing_key   = google_secret_manager_secret.signing_key.id
  }

  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}
