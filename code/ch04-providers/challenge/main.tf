resource "random_pet" "name" {
  length = 2
}

resource "google_compute_network" "main" {
  name                    = "ch04-${random_pet.name.id}"
  auto_create_subnetworks = false
}

# Neither subnet sets "region": each takes it from its provider configuration.
resource "google_compute_subnetwork" "eu" {
  name          = "ch04-${random_pet.name.id}-eu"
  ip_cidr_range = "10.50.0.0/24"
  network       = google_compute_network.main.id
}

resource "google_compute_subnetwork" "us" {
  provider = google.us

  name          = "ch04-${random_pet.name.id}-us"
  ip_cidr_range = "10.50.1.0/24"
  network       = google_compute_network.main.id
}

output "subnet_regions" {
  value = {
    eu = google_compute_subnetwork.eu.region
    us = google_compute_subnetwork.us.region
  }
}
