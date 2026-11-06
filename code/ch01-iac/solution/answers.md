# Chapter 1 exercise — answers

1. Four resources: `google_compute_network`, `google_compute_subnetwork`,
   `google_compute_firewall`, `google_compute_instance`.
2. `hashicorp/google`, exactly version `8.9.0`.
3. `~> 1.17.0` allows any 1.17.x release (1.17.0, 1.17.1, ...) but not 1.18.0.
4. The subnet depends on the network, so Terraform creates the network first
   (and destroys it last). This is an *implicit dependency*.
5. The subnet. The instance's `network_interface` refers to
   `google_compute_subnetwork.web.id`. Through the subnet it also depends on
   the network.
6. TCP port 80 (HTTP), from anywhere (`0.0.0.0/0`).
7. Through **network tags**: the firewall has `target_tags = ["web"]` and the
   instance has `tags = ["web"]`.
8. Every name that starts with `dev-` (network, subnet, firewall, VM), possibly
   the IP range, and usually the project ID — ideally staging lives in its own
   project.
9. Declarative: it describes the desired resources and their settings, not the
   steps to create them. Terraform works out the order from the references.
10. Roughly 30–50 clicks and form fields — and you would need to repeat them
    exactly for every environment.
