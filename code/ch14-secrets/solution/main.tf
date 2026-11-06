resource "google_project_service" "this" {
  for_each = toset(["secretmanager.googleapis.com", "run.googleapis.com"])

  service            = each.value
  disable_on_destroy = false
}

# --- Pattern 2: Terraform generates the value, but never stores it ---------

ephemeral "random_password" "db" {
  length  = 24
  special = true
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "ch14-db-password"

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret                 = google_secret_manager_secret.db_password.id
  secret_data_wo         = ephemeral.random_password.db.result
  secret_data_wo_version = 2 # step 7: bumped from 1 to rotate
}

# --- Pattern 1 + 3: a human adds the value, the app reads it at runtime ----

resource "google_secret_manager_secret" "api_key" {
  secret_id = "ch14-api-key"

  replication {
    auto {}
  }

  depends_on = [google_project_service.this]
}

resource "google_service_account" "app" {
  account_id   = "ch14-app"
  display_name = "Chapter 14 app"
}

resource "google_secret_manager_secret_iam_member" "app_reads_key" {
  secret_id = google_secret_manager_secret.api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}

resource "google_cloud_run_v2_service" "app" {
  name                = "ch14-app"
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.app.email

    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"

      env {
        name = "API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  # The service doesn't reference the IAM binding but needs it to start.
  depends_on = [google_secret_manager_secret_iam_member.app_reads_key]
}
