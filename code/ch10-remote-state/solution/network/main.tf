resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "shared" {
  name                    = "ch10-shared"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "app" {
  name          = "ch10-app"
  ip_cidr_range = "10.30.0.0/24"
  region        = var.region
  network       = google_compute_network.shared.id
}

# A module is a folder of .tf files called with a module block (more in
# Chapter 12). Its outputs are visible here as module.iap_ssh.<name>.
module "iap_ssh" {
  source = "./modules/iap-ssh"

  network_id = google_compute_network.shared.id
  name       = "ch10"
}
