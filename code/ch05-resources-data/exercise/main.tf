# TODO (step 2): enable the Compute Engine API (compute.googleapis.com) with a
# google_project_service resource named "compute". Set disable_on_destroy = false.

resource "google_compute_network" "web" {
  name                    = "ch05-network"
  auto_create_subnetworks = false

  # TODO (step 2): add depends_on so the API is enabled first
}

resource "google_compute_subnetwork" "web" {
  name          = "ch05-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "europe-west1"
  network       = "TODO" # TODO (step 2): reference the network's id (no quotes!)
}

# TODO (step 2): create google_compute_firewall "allow_http" allowing TCP 80 from
# 0.0.0.0/0 to instances tagged "web"

# TODO (step 2): data source google_compute_image "debian" (family debian-12, project debian-cloud)

# TODO (step 2): data source google_compute_zones "available" for region europe-west1
# (it also needs the Compute API, so add depends_on)

resource "google_compute_instance" "web" {
  name         = "ch05-web"
  machine_type = "e2-micro"
  zone         = "TODO" # TODO (step 2): first zone from the zones data source
  tags         = ["web"]

  boot_disk {
    initialize_params {
      image = "TODO" # TODO (step 2): self_link of the debian image data source
    }
  }

  network_interface {
    subnetwork = "TODO" # TODO (step 2): reference the subnet's id
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Hello from Terraform</h1>" > /var/www/html/index.html
  EOT
}

output "web_url" {
  value = "http://${google_compute_instance.web.network_interface[0].access_config[0].nat_ip}"
}
