module "web_app" {
  source = "../../modules/web-app"

  project_id    = var.project_id
  region        = var.region
  environment   = "dev"
  min_instances = 0
  max_instances = 2
  public        = false # the policy library bans allUsers on Cloud Run (Chapter 20)
}
