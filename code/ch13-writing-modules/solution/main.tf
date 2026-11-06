# Step 4: the former google_storage_bucket.logs, now created by the module.
module "logs" {
  source = "./modules/secure-bucket"

  project_id     = var.project_id
  name           = "${var.project_id}-ch13-logs"
  location       = var.region
  retention_days = 30
  force_destroy  = true
  labels         = { purpose = "logs", environment = var.environment }
}

moved {
  from = google_storage_bucket.logs
  to   = module.logs.google_storage_bucket.this
}

# Step 5: reuse the module for several buckets.
module "reports" {
  source   = "./modules/secure-bucket"
  for_each = toset(["finance", "marketing"])

  project_id    = var.project_id
  name          = "${var.project_id}-ch13-${each.key}"
  location      = var.region
  force_destroy = true
  labels        = { purpose = "reports", department = each.key }
}
