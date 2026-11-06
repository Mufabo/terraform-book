resource "google_storage_bucket" "demo" {
  name                        = "${var.project_id}-ch16-hcp"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    managed_by = "hcp-terraform"
  }
}

output "bucket_url" {
  value = google_storage_bucket.demo.url
}
