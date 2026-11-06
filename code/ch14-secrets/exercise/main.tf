resource "google_project_service" "this" {
  for_each = toset([]) # TODO: secretmanager.googleapis.com and run.googleapis.com

  service            = each.value
  disable_on_destroy = false
}

# --- Pattern 2: Terraform generates the value, but never stores it ---------

# TODO: ephemeral "random_password" "db" (length 24, special = true)

resource "google_secret_manager_secret" "db_password" {
  secret_id = "ch14-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}

# TODO: google_secret_manager_secret_version "db_password" using
#   secret_data_wo         = ephemeral.random_password.db.result
#   secret_data_wo_version = 1

# --- Pattern 1 + 3: a human adds the value, the app reads it at runtime ----

# TODO: google_secret_manager_secret "api_key" with secret_id "ch14-api-key"
# (no version — you add the value with gcloud)

# TODO: google_service_account "app" (account_id "ch14-app")

# TODO: google_secret_manager_secret_iam_member giving the service account
#   roles/secretmanager.secretAccessor on the api_key secret

# TODO: google_cloud_run_v2_service "app" running
#   us-docker.pkg.dev/cloudrun/container/hello as the service account,
#   with env var API_KEY from the api_key secret (value_source.secret_key_ref),
#   deletion_protection = false, and depends_on the IAM member.
