locals {
  name = "${var.environment}-${var.app_name}"

  labels = merge(var.labels, {
    environment = var.environment
    app         = var.app_name
    managed_by  = "terraform"
  })
}

resource "google_project_service" "this" {
  for_each = toset(["run.googleapis.com", "iam.googleapis.com"])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_service_account" "app" {
  project      = var.project_id
  account_id   = substr(local.name, 0, 30)
  display_name = "Runtime identity for ${local.name}"

  depends_on = [google_project_service.this]
}

resource "google_storage_bucket" "uploads" {
  project                     = var.project_id
  name                        = "${var.project_id}-${local.name}-uploads"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = !var.deletion_protection
  labels                      = local.labels
}

resource "google_storage_bucket_iam_member" "app_writes_uploads" {
  bucket = google_storage_bucket.uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app.email}"
}

resource "google_cloud_run_v2_service" "app" {
  project             = var.project_id
  name                = local.name
  location            = var.region
  deletion_protection = var.deletion_protection
  labels              = local.labels

  template {
    service_account = google_service_account.app.email

    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      env {
        name  = "UPLOAD_BUCKET"
        value = google_storage_bucket.uploads.name
      }

      env {
        name  = "ENVIRONMENT"
        value = var.environment
      }
    }
  }

  depends_on = [google_project_service.this]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.public ? 1 : 0

  project  = var.project_id
  location = google_cloud_run_v2_service.app.location
  name     = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
