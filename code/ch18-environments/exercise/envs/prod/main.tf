module "web_app" {
  source = "../../modules/web-app"

  project_id = var.project_id
  region     = var.region

  environment = "prod"
  # TODO: min_instances / max_instances (see the exercise steps)
  # TODO: deletion_protection = true
}
