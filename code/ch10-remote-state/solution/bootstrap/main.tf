resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.state_location

  # Keep old versions of the state so mistakes can be undone.
  versioning {
    enabled = true
  }

  # Clean up very old non-current versions.
  lifecycle_rule {
    condition {
      num_newer_versions = 20
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  lifecycle {
    prevent_destroy = true
  }
}
