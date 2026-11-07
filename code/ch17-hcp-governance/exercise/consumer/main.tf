# TODO (step 4): uncomment the module block and the output, and complete the
# source and version. The private registry source can't be used until the
# module is published (steps 1-3).

# module "reports_bucket" {
#   source  = "TODO" # app.terraform.io/<your-org>/secure-bucket/google
#   version = "TODO" # "~> 1.0"
#
#   project_id    = var.project_id
#   name          = "${var.project_id}-ch17-reports"
#   location      = "EU" # step 9: try "US" to trigger the policy
#   force_destroy = true
# }

# output "bucket_url" {
#   value = module.reports_bucket.url
# }
