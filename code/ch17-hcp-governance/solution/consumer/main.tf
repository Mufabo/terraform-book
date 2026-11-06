module "reports_bucket" {
  source  = "app.terraform.io/tf-book-yourname/secure-bucket/google"
  version = "~> 1.0"

  project_id    = var.project_id
  name          = "${var.project_id}-ch17-reports"
  location      = "EU" # step 9: try "US" to trigger the policy
  force_destroy = true
  labels        = { owner = "platform-team" }
}

output "bucket_url" {
  value = module.reports_bucket.url
}
