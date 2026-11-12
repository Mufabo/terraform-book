# After the split: this configuration only manages the shared bucket.
resource "google_storage_bucket" "shared" {
  name                        = "${var.project_id}-ch09c-shared"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true
}
