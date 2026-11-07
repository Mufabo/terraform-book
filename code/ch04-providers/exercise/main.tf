# TODO (step 3): create a random_id resource named "suffix" with byte_length = 4

resource "google_storage_bucket" "eu" {
  name                        = "ch04-eu-TODO" # TODO (step 3): use "ch04-eu-${random_id.suffix.hex}"
  location                    = "EUROPE-WEST1"
  uniform_bucket_level_access = true
  force_destroy               = true
}

# TODO (step 3): create bucket "us" named "ch04-us-<suffix>" in US-CENTRAL1 using provider google.us

# TODO (step 3): create bucket "beta" named "ch04-beta-<suffix>" in EUROPE-WEST1 using provider google-beta
