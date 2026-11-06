resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "eu" {
  name                        = "ch04-eu-${random_id.suffix.hex}"
  location                    = "EUROPE-WEST1"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "us" {
  provider                    = google.us
  name                        = "ch04-us-${random_id.suffix.hex}"
  location                    = "US-CENTRAL1"
  uniform_bucket_level_access = true
  force_destroy               = true
}

resource "google_storage_bucket" "beta" {
  provider                    = google-beta
  name                        = "ch04-beta-${random_id.suffix.hex}"
  location                    = "EUROPE-WEST1"
  uniform_bucket_level_access = true
  force_destroy               = true
}
