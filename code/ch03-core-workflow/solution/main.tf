resource "google_storage_bucket" "notes" {
  name                        = "tf-book-fatih-12345-ch03"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true
  storage_class               = "NEARLINE"

  labels = {
    environment = "learning"
  }

  versioning {
    enabled = true
  }
}
