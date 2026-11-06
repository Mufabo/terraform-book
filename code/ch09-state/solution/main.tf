resource "random_id" "suffix" {
  byte_length = 3
}

resource "google_storage_bucket" "docs" {
  name                        = "ch09-notes-${random_id.suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "this" {
  for_each = var.buckets

  name                        = "ch09-${each.key}-${random_id.suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}
