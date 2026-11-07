module "web_app" {
  source = "../../modules/web-app"

  project_id          = var.project_id
  region              = var.region
  environment         = "prod"
  min_instances       = 0 # use 1+ in real production to avoid cold starts
  max_instances       = 5
  public              = false # the policy library bans allUsers on Cloud Run (Chapter 20)
  deletion_protection = true
}
