# Chapter 5 challenge: answers

**Dependency graph**

```
google_project_service.compute
   ├──▶ google_compute_network.app ──┬──▶ google_compute_subnetwork.app ──┐
   │                                 ├──▶ google_compute_firewall.web_http
   │                                 └──▶ google_compute_firewall.web_to_db
   └──▶ data.google_compute_zones.available ──────────────────────────────┤
data.google_compute_image.debian ─────────────────────────────────────────┤
                                                                          ▼
                                                     google_compute_instance.db
                                                                          │
                                                                          ▼
                                                     google_compute_instance.web
```

* **Created in parallel:** the subnet and the two firewall rules (all three
  depend only on the network).
* **Not in parallel:** the two VMs. The web VM's startup script uses the
  database VM's internal IP address, so Terraform creates `db` first. Without
  that reference they would be created at the same time.
* **Explicit dependencies:** only the two `depends_on` entries on the API.
  Everything else is implicit, from references.
* **Destroy order:** the reverse. `web`, then `db`, then the subnet and the
  firewall rules, then the network.
* **Why the database VM has no `access_config`:** without it the VM gets no
  external IP address, so it can't be reached from the internet at all. The
  `web_to_db` rule only admits traffic from VMs tagged `web`.
