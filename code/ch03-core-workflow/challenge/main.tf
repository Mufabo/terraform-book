resource "google_storage_bucket" "archive" {
  name                        = "tf-book-fatih-12345-ch03-archive"
  location                    = "EU"
  storage_class               = "NEARLINE"
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    purpose = "archive"
  }

  # Delete objects 30 days after they were created.
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}
