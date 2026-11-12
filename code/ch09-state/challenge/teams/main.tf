# After the split: the team buckets live here, with their own state.
resource "google_storage_bucket" "team" {
  for_each = var.teams

  name                        = "${var.project_id}-ch09c-${each.key}"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true
}
