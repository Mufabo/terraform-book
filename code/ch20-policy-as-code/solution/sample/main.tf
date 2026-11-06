resource "google_storage_bucket" "reports" {
  name                        = "${var.project_id}-ch20-reports"
  location                    = var.bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = true

  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }
}

# Deliberately non-compliant: no public access prevention, no labels.
resource "google_storage_bucket" "scratch" {
  name                        = "${var.project_id}-ch20-scratch"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_cloud_run_v2_service" "hello" {
  name                = "ch20-hello"
  location            = var.region
  deletion_protection = false

  labels = {
    environment = "dev"
    managed_by  = "terraform"
  }

  template {
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count = var.public_service ? 1 : 0

  location = google_cloud_run_v2_service.hello.location
  name     = google_cloud_run_v2_service.hello.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
