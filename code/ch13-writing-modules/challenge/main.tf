module "network_dev" {
  source = "./modules/simple-network"

  project_id     = var.project_id
  name           = "ch13c-dev"
  enable_iap_ssh = true

  subnets = {
    app = { region = var.region, cidr = "10.80.0.0/24" }
  }
}

module "network_test" {
  source = "./modules/simple-network"

  project_id = var.project_id
  name       = "ch13c-test"

  subnets = {
    app = { region = var.region, cidr = "10.81.0.0/24" }
    db  = { region = var.region, cidr = "10.81.1.0/24" }
  }
}
