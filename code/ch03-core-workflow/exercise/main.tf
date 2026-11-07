# This file is deliberately badly formatted. Run `terraform fmt` to fix it.
resource "google_storage_bucket" "notes" {
    name = "TODO-your-project-id-ch03"   # TODO (step 3): <your-project-id>-ch03 (names are globally unique)
  location   =    "TODO"                 # TODO (step 3): "EU" or "US"
      # TODO (step 3): enable uniform bucket-level access
   force_destroy = true

  # TODO (step 9): add a label environment = "learning"
  # TODO (step 9): enable versioning with a nested `versioning` block
  # TODO (step 10): set storage_class = "NEARLINE"
}
