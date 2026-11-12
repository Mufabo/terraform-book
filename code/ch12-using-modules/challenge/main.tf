# One VPC per environment from a single module block.
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "18.3.1"

  for_each = var.environments

  project_id   = var.project_id
  network_name = "ch12c-${each.key}"

  subnets = [
    {
      subnet_name   = "app"
      subnet_ip     = cidrsubnet("10.70.0.0/16", 8, each.value)
      subnet_region = var.region
    },
  ]
}

# One bucket per environment from the storage module.
module "buckets" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "12.4.1"

  project_id       = var.project_id
  prefix           = "${var.project_id}-ch12c"
  names            = keys(var.environments)
  location         = var.region
  randomize_suffix = false
  force_destroy    = { for env in keys(var.environments) : env => true }
}
