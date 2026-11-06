# TODO: create a random_id resource named "suffix" with byte_length = 4

resource "google_storage_bucket" "eu" {
  name                        = "ch04-eu-TODO" # TODO: use "ch04-eu-${random_id.suffix.hex}"
  location                    = "EUROPE-WEST1"
  uniform_bucket_level_access = true
  force_destroy               = true
}

# TODO: create bucket "us" in US-CENTRAL1 using provider google.us

# TODO: create bucket "beta" in EUROPE-WEST1 using provider google-beta
