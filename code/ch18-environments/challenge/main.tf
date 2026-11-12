# One root module for every environment. What differs comes from <env>.tfvars.
module "web_app" {
  source = "../solution/modules/web-app"

  project_id          = var.project_id
  region              = var.region
  environment         = var.environment
  app_name            = "tfvars-shop" # keeps clear of the exercise's web-shop
  min_instances       = var.min_instances
  max_instances       = var.max_instances
  public              = true
  deletion_protection = var.deletion_protection
}

output "url" {
  value = module.web_app.url
}
