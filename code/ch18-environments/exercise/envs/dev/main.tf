module "web_app" {
  source = "../../modules/web-app"

  project_id = var.project_id
  region     = var.region

  environment = "dev"
  # TODO: min_instances / max_instances (see the exercise steps)
}
