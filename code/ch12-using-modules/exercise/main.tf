resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "18.3.1"

  project_id   = var.project_id
  network_name = "TODO" # TODO: "ch12-vpc"

  # TODO: subnets — a list of objects with subnet_name, subnet_ip, subnet_region:
  #   web: 10.40.0.0/24 in var.region
  #   db:  10.40.1.0/24 in var.region
  subnets = []

  # TODO: ingress_rules — one rule "ch12-allow-http" allowing tcp/80 from
  # 0.0.0.0/0 to target tag "web". See the module's README for the format.

  depends_on = [google_project_service.compute]
}

module "buckets" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "12.4.1"

  project_id = var.project_id
  # TODO: prefix = var.project_id
  # TODO: names = ["assets", "logs"]
  # TODO: location = var.region
  # TODO: randomize_suffix = false
  # TODO: force_destroy = { assets = true, logs = true }
  names = []
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

resource "google_compute_instance" "web" {
  name         = "ch12-web"
  machine_type = "e2-micro"
  zone         = "${var.region}-b"
  tags         = ["web"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  network_interface {
    subnetwork = "TODO" # TODO: module.vpc.subnets["<region>/web"].self_link
    access_config {}
  }

  metadata_startup_script = "apt-get update && apt-get install -y nginx"
}
