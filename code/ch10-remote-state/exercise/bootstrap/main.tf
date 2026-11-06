resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = var.state_location

  # TODO: enable versioning

  # TODO (optional): lifecycle_rule that deletes ARCHIVED versions when
  # there are more than 20 newer versions

  # TODO: enable uniform bucket-level access
  # TODO: set public_access_prevention = "enforced"
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}
