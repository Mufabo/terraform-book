resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "app" {
  name                    = "ch05c-network"
  auto_create_subnetworks = false

  # The API must be enabled first, but nothing here references it.
  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "app" {
  name          = "ch05c-subnet"
  ip_cidr_range = "10.11.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.app.id
}

# Anyone may reach the web tier on port 80.
resource "google_compute_firewall" "web_http" {
  name    = "ch05c-web-http"
  network = google_compute_network.app.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
}

# Only the web tier may reach the database tier on port 5432.
resource "google_compute_firewall" "web_to_db" {
  name    = "ch05c-web-to-db"
  network = google_compute_network.app.id

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_tags = ["web"]
  target_tags = ["db"]
}

data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}

data "google_compute_zones" "available" {
  region = "europe-west1"

  depends_on = [google_project_service.compute]
}

resource "google_compute_instance" "web" {
  name         = "ch05c-web"
  machine_type = "e2-micro"
  zone         = data.google_compute_zones.available.names[0]
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
    subnetwork = google_compute_subnetwork.app.id
    access_config {} # public IP address
  }

  # The page shows the database VM's internal address. This reference makes
  # the web VM depend on the database VM.
  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Web tier. Database at ${google_compute_instance.db.network_interface[0].network_ip}</h1>" > /var/www/html/index.html
  EOT
}

resource "google_compute_instance" "db" {
  name         = "ch05c-db"
  machine_type = "e2-micro"
  zone         = data.google_compute_zones.available.names[0]
  tags         = ["db"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.debian.self_link
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  network_interface {
    subnetwork = google_compute_subnetwork.app.id
    # No access_config block: internal address only.
  }
}

output "web_url" {
  value = "http://${google_compute_instance.web.network_interface[0].access_config[0].nat_ip}"
}

output "db_internal_ip" {
  value = google_compute_instance.db.network_interface[0].network_ip
}
