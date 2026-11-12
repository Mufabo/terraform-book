# Chapter 12 — Using Modules

## Learning objectives

By the end of this lesson you will be able to:

* Explain what a module is and why modules are used. `[5c]`
* Describe the module **sources** Terraform supports: local paths, the
  Terraform Registry, Git, and others. `[5a]`
* Call a module, pass inputs, and use its outputs. `[5c]`
* Pin and upgrade **module versions**. `[5d]`
* Find and evaluate modules on the public registry, including Google's
  `terraform-google-modules`. `[5a]`

**Time:** about 45 minutes — 15 reading, 5 quick check, 25 exercise.

---

## 12.1 What is a module?

A **module** is simply a folder of `.tf` files. You've been writing modules
all along: the directory where you run `terraform` is the **root module**.
When the root module *calls* another module, that one is a **child module**.

```
root module (your working directory)
├── module "network"   → a child module (e.g. from the registry)
│     └── resources: network, subnets, routes
└── module "buckets"   → another child module
      └── resources: buckets, IAM bindings
```

Why use modules?

* **Reuse** — write "a secure bucket" once, use it everywhere.
* **Abstraction** — users set a few meaningful inputs instead of 40
  arguments.
* **Consistency** — every team builds networks the same, approved way.
* **Encapsulation** — related resources are grouped and versioned together.

Just like functions in programming: inputs (variables), a body (resources),
and outputs.

## 12.2 Calling a module `[5c]`

```hcl
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "18.3.1"

  project_id   = var.project_id
  network_name = "ch12-vpc"

  subnets = [
    {
      subnet_name   = "web"
      subnet_ip     = "10.40.0.0/24"
      subnet_region = "europe-west1"
    },
  ]
}
```

* The label (`"vpc"`) is the **module name** in your configuration.
* `source` (required) says where the module code lives.
* `version` constrains the version (only for registry sources).
* All other arguments are the module's **input variables**.

Modules also accept the meta-arguments `count`, `for_each`, `depends_on`, and
`providers`:

```hcl
module "bucket" {
  source   = "./modules/bucket"
  for_each = toset(["logs", "backups"])
  name     = each.key
}
```

After adding or changing a module, run **`terraform init`** — it downloads
modules into `.terraform/modules/`.

### Using module outputs

A module exposes values through its outputs. Refer to them as
`module.<NAME>.<OUTPUT>`:

```hcl
resource "google_compute_instance" "web" {
  # ...
  network_interface {
    subnetwork = module.vpc.subnets_self_links[0]
  }
}

output "network_name" {
  value = module.vpc.network_name
}
```

You **can't** reach inside a module to refer to its resources directly
(`module.vpc.google_compute_network.network` is not valid in expressions).
Only outputs are accessible. In state and plans, however, resources inside
modules have addresses like `module.vpc.module.vpc.google_compute_network.network`.

## 12.3 Module sources `[5a]`

| Source type | Example `source` | Version via |
|---|---|---|
| **Local path** | `"./modules/bucket"`, `"../shared/network"` | — (same repo) |
| **Terraform Registry** | `"terraform-google-modules/network/google"` | `version` argument |
| **Private registry** (HCP Terraform) | `"app.terraform.io/acme/network/google"` | `version` argument |
| **GitHub** | `"github.com/acme/tf-modules//network?ref=v1.2.0"` | `?ref=` |
| **Generic Git** | `"git::https://example.com/modules.git//network?ref=v1.2.0"` | `?ref=` |
| **GCS bucket** | `"gcs::https://www.googleapis.com/storage/v1/acme-modules/network.zip"` | — |
| **HTTP URL / S3** | `"https://example.com/network.zip"` | — |

Notes:

* **Local paths** must start with `./` or `../`; they're not downloaded but
  used in place. Great for modules inside the same repository.
* **Registry addresses** have the format `<NAMESPACE>/<NAME>/<PROVIDER>`, e.g.
  `terraform-google-modules/network/google`.
* The **double slash** `//` selects a sub-directory inside a repository or
  archive: `github.com/acme/modules//network`.
* `?ref=` selects a Git branch, tag, or commit. Pin to a **tag or commit**,
  never to a moving branch like `main`.

## 12.4 Module versions `[5d]`

For registry modules, the `version` argument accepts the same constraint
syntax as providers (Chapter 4):

```hcl
module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "18.3.1"        # exact pin (this book's choice)
  # version = "~> 18.3"     # any 18.x from 18.3 upwards
}
```

Important facts:

* The `version` argument works **only for registry sources** (public or
  private). For Git sources use `?ref=`. Local modules have no version.
* Module versions are **not** recorded in `.terraform.lock.hcl` — the lock
  file covers providers only. So pin module versions explicitly.
* `terraform init` downloads the newest version matching the constraint *if
  the module isn't already installed*. `terraform init -upgrade` re-checks and
  upgrades modules (and providers) to the newest allowed versions.
* Modules follow **semantic versioning**: a major version bump (18 → 19)
  signals breaking changes. Read the upgrade guide before changing it.

> **Exam tip:** "How do you specify a version for a module from GitHub?" →
> `?ref=` in the source URL, not the `version` argument. "Does the lock file
> track module versions?" → No.

### Modules and providers

A child module declares the providers it needs (and usually a *minimum*
version) in its own `required_providers`. Your root module must supply a
provider version that satisfies **every** module's constraints. For example,
the network module 18.3.1 requires `google >= 4.64, < 9`, which our pinned
8.9.0 satisfies.

By default, child modules **inherit** the default provider configurations
from the root. To pass an aliased provider explicitly:

```hcl
module "vpc_us" {
  source  = "terraform-google-modules/network/google"
  version = "18.3.1"

  providers = {
    google = google.us
  }
  # ...
}
```

## 12.5 Finding good modules on the registry

The public registry at <https://registry.terraform.io/browse/modules> lists
thousands of modules. Each page shows the README, inputs, outputs,
dependencies, resources, and examples.

For Google Cloud, the **`terraform-google-modules`** namespace contains
modules maintained by Google (part of "Cloud Foundation Toolkit"), for
example:

| Module | Purpose |
|---|---|
| `terraform-google-modules/network/google` | VPC networks, subnets, routes, firewall rules |
| `terraform-google-modules/cloud-storage/google` | Buckets with IAM and lifecycle rules |
| `terraform-google-modules/project-factory/google` | Projects with APIs, billing, service accounts |
| `terraform-google-modules/kubernetes-engine/google` | GKE clusters |
| `terraform-google-modules/sql-db/google` | Cloud SQL databases |

Badges such as **Partner** or **Verified** indicate that the publisher has
been checked by HashiCorp.

### How to evaluate a module

* **Maintainer** — official/partner or an active community project?
* **Activity** — recent releases, open issues being addressed?
* **Provider constraints** — compatible with your provider version?
* **Inputs and outputs** — does it expose what you need?
* **Code quality** — read the source. A module is code you run with your
  credentials.
* **Licence** — acceptable for your organisation?

Public modules are powerful but sometimes complex. Many organisations wrap
them, or write their own (Chapter 13), and publish them in a **private
registry** (Chapter 17).

## 12.6 Inspecting modules

```console
$ terraform init
Initializing modules...
Downloading registry.terraform.io/terraform-google-modules/network/google 18.3.1 for vpc...
- vpc in .terraform/modules/vpc
- vpc.firewall_rules in .terraform/modules/vpc/modules/firewall-rules
- vpc.private_service_access in .terraform/modules/vpc/modules/private-service-access
- vpc.routes in .terraform/modules/vpc/modules/routes
- vpc.subnets in .terraform/modules/vpc/modules/subnets
- vpc.vpc in .terraform/modules/vpc/modules/vpc

$ terraform state list
module.vpc.module.subnets.google_compute_subnetwork.subnetwork["europe-west1/web"]
module.vpc.module.vpc.google_compute_network.network
```

`.terraform/modules/modules.json` records which modules were installed from
where. Modules can contain other modules (nested modules), as you can see
above.

## Common mistakes and exam tips

* Forgetting `terraform init` after adding a module → "Module not installed".
* Using `version` with a Git or local source → error.
* Pinning a Git source to a branch → unpredictable changes.
* Trying to reference a resource inside a module → only outputs are
  accessible.
* Expecting the lock file to pin modules.

## Summary

* A module is a folder of Terraform files; the working directory is the root
  module, and it can call child modules.
* `source` says where a module comes from: local path, registry, Git, HTTP,
  buckets.
* Pin registry modules with `version`, Git modules with `?ref=`.
* Pass inputs as arguments; read outputs with `module.NAME.OUTPUT`.
* `terraform init` installs modules; `init -upgrade` upgrades them.

## Quick check

1. What's the difference between a root module and a child module?
2. How do you pin a module stored in a GitHub repository to version `v2.0.1`?
3. How do you refer to an output called `network_name` of a module called
   `vpc`?
4. Are module versions recorded in `.terraform.lock.hcl`?
5. What does `//` mean in `github.com/acme/modules//network`?

---

## Hands-on exercise: Build with public modules

**Goal:** Create a network and buckets using two modules from
`terraform-google-modules`, and connect a VM to the module's outputs.

**Estimated time:** 25 minutes

**Files:** `code/ch12-using-modules/exercise/`

### Steps

1. `cd code/ch12-using-modules/exercise` and create `terraform.tfvars`.
2. Open the registry pages for `terraform-google-modules/network/google`
   (version 18.3.1) and `terraform-google-modules/cloud-storage/google`
   (version 12.4.1). Skim the **Inputs** and **Outputs** tabs.
3. Complete the `module "vpc"` block: network name `ch12-vpc`, two subnets
   (`web` in `europe-west1` with `10.40.0.0/24`, `db` in `europe-west1` with
   `10.40.1.0/24`), and a firewall rule allowing HTTP to the tag `web` (use
   the module's `ingress_rules` input).
4. Complete the `module "buckets"` block to create two buckets named
   `assets` and `logs` with a prefix of your project ID.
5. Complete the VM so it uses the `web` subnet from the module's outputs.
6. Run `terraform init` and look at the "Initializing modules" output and the
   `.terraform/modules` folder.
7. `terraform plan` and `terraform apply`. Then `terraform state list` — look
   at the module addresses.
8. Change the network module `version` to `"~> 18.0"` and run
   `terraform init`. Does it download anything? Run `terraform init -upgrade`.
   Change it back to `"18.3.1"`.

### Expected result

A VPC with two subnets and a firewall rule, two buckets, and a VM in the
`web` subnet — written with very few lines of your own code.

### Stretch goal

Look at the module's source in `.terraform/modules/vpc`. Find the resource
that creates the network. How many input variables does the module have?

### Cleanup

```console
$ terraform destroy
```

---

## Quick check answers

1. The root module is the working directory where you run Terraform; a child
   module is any module called from another module.
2. `source = "github.com/<org>/<repo>?ref=v2.0.1"` (the `version` argument
   doesn't work for Git sources).
3. `module.vpc.network_name`
4. No — only providers.
5. A sub-directory inside the repository (`network`).
