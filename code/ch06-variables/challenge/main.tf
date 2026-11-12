locals {
  bucket_name = "${var.project_id}-${var.team}-${var.environment}"

  common_labels = merge(var.labels, {
    team        = var.team
    environment = var.environment
    managed_by  = "terraform"
  })
}

resource "google_storage_bucket" "team" {
  name                        = local.bucket_name
  location                    = var.bucket.location
  storage_class               = var.bucket.storage_class
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = local.common_labels

  versioning {
    enabled = var.bucket.versioning
  }

  # Deleted objects can be restored for this long. The API wants seconds.
  soft_delete_policy {
    retention_duration_seconds = var.bucket.soft_delete_days * 24 * 60 * 60
  }
}
