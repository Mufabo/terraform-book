# Generated with -generate-config-out, then tidied up (step 2).
resource "google_storage_bucket" "site" {
  name                        = "${var.project_id}-legacy-site"
  location                    = "EUROPE-WEST1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    team = "marketing" # was "web"; accepted drift (step 4)
  }
}

# Step 3: google_storage_bucket.media was imported with `terraform import`.
# Step 6: it was renamed to "assets" with a moved block.
# Step 7: it was released from management. The moved block was deleted
# together with the resource, and this removed block keeps the real bucket.
removed {
  from = google_storage_bucket.assets

  lifecycle {
    destroy = false
  }
}
