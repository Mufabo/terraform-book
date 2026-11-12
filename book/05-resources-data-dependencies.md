# Chapter 5 — Resources, Data Sources, and Dependencies

## Learning objectives

By the end of this lesson you will be able to:

* Explain the difference between `resource` and `data` blocks and use both. `[4a]`
* Refer to resource attributes and create cross-resource references. `[4b]`
* Explain how Terraform builds a **dependency graph** from references
  (implicit dependencies). `[4f]`
* Declare explicit dependencies with `depends_on`, and know when it is
  needed. `[4f]`
* Build a small network with a web server on Google Cloud.

**Time:** about 55 minutes — 25 reading, 5 quick check, 25 exercise.

---

## 5.1 Resources: things Terraform manages `[4a]`

A `resource` block describes an infrastructure object that Terraform
**creates, updates, and deletes**: a bucket, a network, a virtual machine, an
IAM binding.

```hcl
resource "google_compute_network" "web" {
  name                    = "web-network"
  auto_create_subnetworks = false
}
```

Each resource type has:

* **Arguments** — values *you* set (`name`, `auto_create_subnetworks`).
  Some are required, some optional. The provider documentation lists them.
* **Attributes** — values you can *read*, including all the arguments plus
  values computed by the provider after creation (`id`, `self_link`,
  `gateway_ipv4`). The docs list these under "Attributes Reference".

### Meta-arguments

Besides the provider-specific arguments, every resource accepts a few
**meta-arguments** defined by Terraform itself:

| Meta-argument | Purpose | Chapter |
|---|---|---|
| `depends_on` | Explicit dependencies | this chapter |
| `provider` | Select a non-default provider configuration | 4 |
| `count` | Create several instances by number | 7 |
| `for_each` | Create several instances from a map or set | 7 |
| `lifecycle` | Customise create/update/destroy behaviour | 8 |

`data` blocks (section 5.5) accept the same meta-arguments, though
`lifecycle` supports only `precondition` and `postcondition` there.

## 5.2 Referencing attributes `[4b]`

To use an attribute of one resource in another, write a **reference
expression**:

```
<RESOURCE TYPE>.<LOCAL NAME>.<ATTRIBUTE>
```

```hcl
resource "google_compute_subnetwork" "web" {
  name          = "web-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.web.id   # reference
}
```

`google_compute_network.web.id` reads the `id` attribute of the network
resource. The ID isn't known until the network exists, so the plan shows
`(known after apply)`, and Terraform fills it in during the apply.

Nested blocks are accessed like lists. For a VM's external IP:

```hcl
google_compute_instance.web.network_interface[0].access_config[0].nat_ip
```

`network_interface` is a list of blocks; `[0]` picks the first one. (Some
nested blocks are *sets* instead, which have no order and can't be indexed.
The provider docs don't always say which is which. If `[0]` gives an error,
the block is a set.)

## 5.3 Implicit dependencies and the graph `[4f]`

Because the subnet *references* the network, Terraform knows the subnet
**depends on** the network. From all references it builds a **dependency
graph** and uses it to:

* **Create** resources in the right order (network → subnet → VM).
* **Destroy** in the reverse order (VM → subnet → network).
* **Parallelise** independent work. Resources that don't depend on each
  other are created at the same time (up to 10 at once by default; change
  with `-parallelism=N`).

These are called **implicit dependencies**: you didn't declare them, they come
from references. **Prefer implicit dependencies** — they're automatic and
always correct.

You can visualise the graph:

```console
$ terraform graph | dot -Tsvg > graph.svg
```

(`dot` is part of the free Graphviz package.)

## 5.4 Explicit dependencies: `depends_on` `[4f]`

Sometimes resource B needs resource A to exist, but B doesn't reference any
of A's attributes. Terraform can't see that relationship, so you tell it with
`depends_on`.

The classic Google Cloud example is **enabling an API**:

```hcl
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "web" {
  name                    = "web-network"
  auto_create_subnetworks = false

  depends_on = [google_project_service.compute]
}
```

The network doesn't use any value from `google_project_service.compute`, but
the Compute Engine API must be enabled before a network can be created.
Without `depends_on`, Terraform might try both at the same time, and the
network creation would fail.

Another common case: an application needs an **IAM permission** to be
granted before it starts, but doesn't reference the IAM binding.

Rules for `depends_on`:

* Its value is a **list of references** (no quotes): `[google_project_service.compute]`.
* You can depend on a whole resource or a module, not on a single attribute.
* `data` blocks accept `depends_on` too (section 5.6 uses it).
* Use it **only when necessary** and add a comment explaining why. Too many
  `depends_on` entries add ordering that isn't needed, so less runs in
  parallel. On a data source it also costs something at plan time: if anything
  it depends on has pending changes, Terraform waits until the apply to read
  it, so its values become "known after apply" (section 5.5).

> **Exam tip:** "Terraform can't infer a dependency because there is no
> reference — what do you use?" → `depends_on`. "Which is preferred, implicit
> or explicit?" → implicit.

## 5.5 Data sources: reading existing information `[4a]`

A `data` block **reads** information from the provider without managing
anything. Data sources let you use objects created outside this configuration
— by another team, by another Terraform configuration, or by Google itself.

```hcl
data "google_compute_image" "debian" {
  family  = "debian-12"
  project = "debian-cloud"
}
```

This looks up the newest image in the `debian-12` family published by Google.
You refer to it with the `data.` prefix:

```
data.<TYPE>.<NAME>.<ATTRIBUTE>
```

```hcl
boot_disk {
  initialize_params {
    image = data.google_compute_image.debian.self_link
  }
}
```

### `resource` vs `data` side by side

| | `resource` | `data` |
|---|---|---|
| Purpose | Create and manage an object | Read an existing object |
| Changes infrastructure? | Yes | Never |
| Deleted by `destroy`? | Yes | No (nothing to delete) |
| Reference syntax | `TYPE.NAME.ATTR` | `data.TYPE.NAME.ATTR` |
| Plan symbol | `+`, `~`, `-`, `-/+` | `<=` (read during apply) |

Data sources are usually read during `plan` (and `refresh`). A data source
read during plan doesn't appear in the plan's list of changes, only as
`Reading...` / `Read complete` lines in the progress output. Terraform
**defers** the read until the apply in two cases:

* one of its arguments is only known after apply, or
* it has `depends_on` on a resource or module that has pending changes.

Only deferred reads show up in the plan, with the `<=` symbol:

```
  # data.google_compute_zones.available will be read during apply
  # (depends on a resource or a module with changes pending)
 <= data "google_compute_zones" "available" {
      + id      = (known after apply)
      + names   = (known after apply)
      + project = (known after apply)
      + region  = "europe-west1"
    }
```

Anything that uses the data source's values is then "known after apply" as
well.

### Useful Google data sources

| Data source | Returns |
|---|---|
| `google_project` | Project ID, number, labels |
| `google_client_config` | The project, region, and access token Terraform is using |
| `google_compute_zones` | Available zones in a region |
| `google_compute_image` | An image by name or family |
| `google_compute_network` | An existing network (e.g. a shared VPC) |
| `google_secret_manager_secret_version` | A secret's value (Chapter 14) |
| `google_iam_policy` | Builds an IAM policy document |

Example: pick the first available zone in a region instead of hard-coding it.

```hcl
data "google_compute_zones" "available" {
  region = "europe-west1"
}

resource "google_compute_instance" "web" {
  zone = data.google_compute_zones.available.names[0]
  # ...
}
```

## 5.6 Putting it together: a web server

Here is a complete small system. Read it carefully and trace the references.

```hcl
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false
}

resource "google_compute_network" "web" {
  name                    = "ch05-network"
  auto_create_subnetworks = false

  # The API must be enabled first, but nothing here references it.
  depends_on = [google_project_service.compute]
}

resource "google_compute_subnetwork" "web" {
  name          = "ch05-subnet"
  ip_cidr_range = "10.10.0.0/24"
  region        = "europe-west1"
  network       = google_compute_network.web.id
}

resource "google_compute_firewall" "allow_http" {
  name    = "ch05-allow-http"
  network = google_compute_network.web.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web"]
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
  name         = "ch05-web"
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
    subnetwork = google_compute_subnetwork.web.id
    access_config {} # gives the VM a public IP address
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
```

A few new things:

* `<<-EOT ... EOT` is a **heredoc**: a multi-line string. The `-` strips
  leading indentation.
* `metadata_startup_script` runs the script every time the VM boots.
  Changing it forces Terraform to replace the VM.
* `shielded_instance_config` turns on **Secure Boot**, which only lets
  verified boot software start; the Debian image supports it. Many companies
  require it with the organization policy `compute.requireShieldedVm`.
  Without the block, creating the VM in such an organization fails with
  `Constraint constraints/compute.requireShieldedVm violated ... Secure Boot
  is not enabled`. Every VM in this book sets it, so the code works with or
  without that policy.
* You already enabled the Compute Engine API with `gcloud` in Chapter 2.
  `google_project_service` adopts an API that is already enabled, so the plan
  still shows it as `+ create`. With `disable_on_destroy = false`, `destroy`
  removes it from state but leaves the API enabled.
* The zones data source has `depends_on` on the API. On the first plan, the API
  resource is still to be created, so Terraform waits until the apply to read
  the zones (section 5.5), and the VM's `zone` shows as `(known after apply)`.
  The image data source has no dependencies, so Terraform reads it during plan.
* `output` prints a value after `apply` (Chapter 6 covers outputs).

> [!NOTE]
> **Google Cloud: Compute Engine VMs.** **Compute Engine** is Google Cloud's
> virtual machine service. A VM, also called an *instance*, lives in one zone
> and is made of:
>
> * A **machine type**, which sets CPUs and memory. `e2-micro` is the
>   smallest general-purpose type: 2 shared vCPUs and 1 GB of memory.
> * A **boot disk** created from an **image**. Google publishes images in
>   public projects such as `debian-cloud`, grouped into **image families**
>   like `debian-12`; a family always points to its newest image.
> * One or more **network interfaces**, each in a subnet. An `access_config`
>   block adds an external IP address; without it, the VM has only an
>   internal one.
> * **Metadata**: key/value pairs the VM can read from inside, such as its
>   startup script and SSH keys.
>
> A running VM is billed per second; its disk is billed even while the VM is
> stopped. One `e2-micro` per month is free, but only in a few US regions, not
> in `europe-west1` (Appendix D).

The dependency graph:

```
google_project_service.compute
   ├──▶ google_compute_network.web ──┬──▶ google_compute_subnetwork.web ──┐
   │                                 └──▶ google_compute_firewall.allow_http
   └──▶ data.google_compute_zones.available ──────────────────────────────┤
data.google_compute_image.debian ─────────────────────────────────────────┤
                                                                          ▼
                                                        google_compute_instance.web
```

The firewall and subnet don't depend on each other, so Terraform creates them
in parallel.

> **Note:** The firewall rule doesn't reference the VM (it uses the `web` tag),
> and the VM doesn't reference the firewall. That's fine: firewall rules apply
> to any instance with a matching tag, whenever it is created.

> [!NOTE]
> **Google Cloud: VPC networks and subnets.** A **VPC network** (Virtual
> Private Cloud) is a private network for your resources. On Google Cloud a
> network is **global**: one network spans all regions. IP address ranges
> belong to **subnets**, which are **regional**. `ch05-subnet` provides the
> range `10.10.0.0/24` (256 addresses, four of which Google reserves) in
> `europe-west1`, and the VM gets its internal IP address from it. Resources
> in the same network reach each other over internal addresses, even across
> regions; separate networks are isolated unless you connect them. An
> *auto mode* network gets a subnet in every region automatically, like the
> `default` network from section 2.5. `auto_create_subnetworks = false` makes
> a *custom mode* network, where you decide which subnets exist. Production
> networks use custom mode.

> [!NOTE]
> **Google Cloud: firewall rules and network tags.** Firewall rules belong to
> a network and filter the traffic to and from its VMs. Every network starts
> with two hidden *implied* rules: all incoming (**ingress**) traffic is
> denied, and all outgoing (**egress**) traffic is allowed. You then add rules
> that open exactly what you need. `ch05-allow-http` allows TCP port 80 from
> anywhere (`0.0.0.0/0`), but only to VMs that carry the **network tag**
> `web`. Network tags are plain strings on a VM (`tags = ["web"]`) that
> firewall rules can target; they have nothing to do with labels. When several
> rules match, the one with the lowest `priority` number (default 1000) wins.

## 5.7 Resource behaviour you should know

* **Create**: a resource in config but not in state is created.
* **Destroy**: a resource in state but no longer in config is destroyed.
* **Update in place**: an argument changed that the API can update.
* **Replace**: an argument changed that can't be updated (e.g. a VM's
  `zone`, a bucket's `location`). The plan says `forces replacement`.
* **Timeouts**: some resources take a long time (databases). Many support a
  nested `timeouts { create = "30m" }` block.

## Common mistakes and exam tips

* Forgetting the `data.` prefix when referencing a data source.
* Writing references as strings: `network = "google_compute_network.web.id"`
  sets the literal text, not the ID. Don't quote references.
* Using `depends_on` everywhere "just in case". Prefer references.
* Data sources **don't** create anything; if the object doesn't exist, the plan
  fails.
* `terraform destroy` removes resources, never "data".

## Summary

* `resource` blocks manage infrastructure; `data` blocks read it.
* Reference attributes with `TYPE.NAME.ATTR` and `data.TYPE.NAME.ATTR`.
* References create **implicit dependencies**; Terraform builds a graph to
  order and parallelise operations.
* Use `depends_on` only for hidden dependencies, such as enabling an API or
  waiting for IAM.

## Quick check

1. What is the reference expression for the `self_link` attribute of a data
   source `google_compute_image` named `ubuntu`?
2. Why does `google_compute_subnetwork.web` get created after
   `google_compute_network.web` even though you never said so?
3. Give an example where `depends_on` is required.
4. What plan symbol is used for reading a data source?
5. In which order does Terraform destroy a network, a subnet, and a VM?

---

## Hands-on exercise: A web server in its own network

**Goal:** Build a VPC network, subnet, firewall rule, and VM running nginx,
using data sources and both implicit and explicit dependencies.

**Estimated time:** 25 minutes

**Files:** `code/ch05-resources-data/exercise/`

### Steps

1. `cd code/ch05-resources-data/exercise` and set your project ID in
   `providers.tf`.
2. Complete the `TODO (step 2)`s in `main.tf`:
   * Enable `compute.googleapis.com` with `google_project_service`.
   * Create the network with `depends_on` on the API.
   * Create the subnet and firewall rule, referencing the network.
   * Add the `google_compute_image` and `google_compute_zones` data sources.
   * Create the VM using the data sources and the subnet.
3. Run `terraform init`, `terraform validate`, and `terraform plan`. In the
   plan, find the one `<=` read (the zones data source, deferred because of
   its `depends_on`) and the `(known after apply)` values. The image data
   source doesn't appear in the plan; look for its `Read complete` line in the
   output above the plan instead.
4. Run `terraform apply`. Notice in the output which resources are created in
   parallel.
5. Wait a minute or two for the startup script, then open the `web_url`
   output (`terraform output web_url`) in a browser. You should see "Hello from Terraform".
6. Run `terraform graph` and paste the output into
   <https://dreampuf.github.io/GraphvizOnline> (or use `dot` locally) to see
   the graph.
7. Change the VM's `machine_type` to `e2-small` and plan. The plan shows an
   in-place update (`~`), but a running VM must be stopped to change its
   machine type, so the apply would fail unless you also set
   `allow_stopping_for_update = true`. The plan only shows what Terraform
   intends to do; the API can still refuse it. Revert to `e2-micro` without
   applying.

### Expected result

A browser page showing "Hello from Terraform" served by your VM.

### Stretch goal

Add a second firewall rule that allows SSH (TCP 22) only from Google's
Identity-Aware Proxy range `35.235.240.0/20`, then connect with
`gcloud compute ssh ch05-web --tunnel-through-iap --zone <zone>`.

> [!NOTE]
> **Google Cloud: Identity-Aware Proxy (IAP).** IAP **TCP forwarding** lets
> you reach a VM's SSH port without opening it to the internet, and even
> without an external IP address. With `--tunnel-through-iap`, `gcloud`
> connects to Google, IAM checks that you may use the tunnel (as project Owner
> you may; others need `roles/iap.tunnelResourceAccessor`), and Google then
> opens the connection to the VM from the range `35.235.240.0/20`. That's why
> the firewall rule only has to allow that range. Chapter 10's `iap-ssh`
> module uses the same pattern.

> [!NOTE]
> **Google Cloud: where your SSH key goes.** The first time you run
> `gcloud compute ssh`, it creates a key pair in `~/.ssh/google_compute_engine`
> (it may ask for a passphrase) and adds the public key to your **project's**
> metadata under `ssh-keys`. Every VM in the project then accepts it.
> `terraform destroy` doesn't remove it, because Terraform never managed it.
> It does no harm, but you can see it with
> `gcloud compute project-info describe --format="value(commonInstanceMetadata.items)"`
> and remove it with
> `gcloud compute project-info remove-metadata --keys=ssh-keys`.

> [!NOTE]
> **Google Cloud: the NumPy warning.** When connecting through IAP, `gcloud` may print
> `To increase the performance of the tunnel, consider installing NumPy`.
> You can ignore it: the connection works without NumPy, only large file
> transfers over the tunnel are slower.

### Challenge

*Optional, about 35 minutes. There are no starter files and no `TODO`s: work
in a new, empty folder from the requirements alone. A reference solution is in
`code/ch05-resources-data/challenge/`.*

Build a two-tier setup: a web VM that the internet can reach, and a
database VM that only the web VM can reach.

* The Compute Engine API enabled with Terraform; a custom-mode network and
  one subnet (`10.11.0.0/24`). Use names that don't clash with the exercise,
  for example with the prefix `ch05c-`.
* A VM `web` (tag `web`) with a public IP address and nginx, and a VM `db`
  (tag `db`) **without** a public IP address. Both are `e2-micro`, use the
  newest Debian 12 image from a data source, a zone from a data source, and
  Secure Boot.
* Firewall rules: TCP 80 from anywhere to `web`; TCP 5432 to `db`, but
  **only from VMs tagged `web`** (the firewall resource's documentation
  shows how to name a tag as the source).
* The web page must show the database VM's internal IP address.
* Outputs: the web URL and the database VM's internal IP address.

Before you apply, draw the dependency graph and answer: which resources will
Terraform create in parallel? Are the two VMs created in parallel? Which
dependencies are explicit?

**Done when** the web page shows the internal IP address from your output,
and your graph matches what `terraform apply` did. Destroy both VMs when
you're finished; two VMs cost twice as much as one.

### Cleanup

```console
$ terraform destroy
```

The Compute Engine API stays enabled (`disable_on_destroy = false`). Later
chapters need it.

> **Cost note:** One `e2-micro` VM is in the free tier in some US regions
> (`us-west1`, `us-central1`, `us-east1`). Elsewhere it costs around a cent an
> hour, plus a small charge for its external IP address and boot disk. Always
> destroy when finished.

---

## Quick check answers

1. `data.google_compute_image.ubuntu.self_link`
2. Because the subnet references `google_compute_network.web.id`, creating an
   implicit dependency.
3. Enabling an API (`google_project_service`) before creating resources that
   use it; granting an IAM role before a service that needs it starts.
4. `<=`
5. Reverse dependency order: VM, then subnet, then network.
