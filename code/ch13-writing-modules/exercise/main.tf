# Step 2: a plain resource. Apply it first.
resource "google_storage_bucket" "logs" {
  name                        = "${var.project_id}-ch13-logs"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

# Step 4: replace the resource above with:
#   module "logs" { source = "./modules/secure-bucket" ... retention_days = 30 }
# and add a moved block from google_storage_bucket.logs to
# module.logs.google_storage_bucket.this

# Step 5: module "reports" with for_each = toset(["finance", "marketing"])
