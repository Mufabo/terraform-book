module "web_app" {
  source = "../../modules/web-app"

  project_id          = var.project_id
  region              = var.region
  environment         = "prod"
  min_instances       = 0 # use 1+ in real production to avoid cold starts
  max_instances       = 5
  public              = true
  deletion_protection = true
}
