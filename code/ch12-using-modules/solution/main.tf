resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "18.3.1"

  project_id   = var.project_id
  network_name = "ch12-vpc"

  subnets = [
    {
      subnet_name   = "web"
      subnet_ip     = "10.40.0.0/24"
      subnet_region = var.region
    },
    {
      subnet_name   = "db"
      subnet_ip     = "10.40.1.0/24"
      subnet_region = var.region
    },
  ]

  ingress_rules = [
    {
      name          = "ch12-allow-http"
      source_ranges = ["0.0.0.0/0"]
      target_tags   = ["web"]
      allow = [
        {
          protocol = "tcp"
          ports    = ["80"]
        },
      ]
    },
  ]

  depends_on = [google_project_service.compute]
}

module "buckets" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "12.4.1"

  project_id       = var.project_id
  prefix           = var.project_id
  names            = ["assets", "logs"]
  location         = var.region
  randomize_suffix = false
  force_destroy = {
    assets = true
    logs   = true
  }
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

  shielded_instance_config {
    enable_secure_boot = true
  }

  network_interface {
    subnetwork = module.vpc.subnets["${var.region}/web"].self_link
    access_config {}
  }

  metadata_startup_script = "apt-get update && apt-get install -y nginx"
}
