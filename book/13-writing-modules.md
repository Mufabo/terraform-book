# Chapter 13 — Writing Your Own Modules

## Learning objectives

By the end of this lesson you will be able to:

* Structure a reusable module with inputs, outputs, and documentation. `[5c]`
* Explain **variable scope** within modules: what a child module can and
  can't see. `[5b]`
* Pass data between modules and compose small modules into larger systems. `[5b]`
* Decide where provider configuration and version constraints belong in a
  module.
* Refactor existing resources into a module without re-creating them.
* Describe how modules are versioned and published. `[5d]`

---

## 13.1 When to write a module

Write a module when you have a **reusable pattern** — something you build
repeatedly with small variations:

* "A secure bucket": uniform access, public access prevention, versioning,
  labels, optional IAM.
* "A web service": Cloud Run service, service account, IAM, domain mapping.
* "A standard network": VPC, subnets, NAT, firewall baseline.

Don't write a module that just wraps a single resource with the same
arguments — it adds a layer without adding value. A good module **raises the
level of abstraction**: users describe *what* they need ("a private bucket
for logs, kept 30 days") instead of *how*.

## 13.2 Standard module structure

```
modules/secure-bucket/
├── main.tf          # resources
├── variables.tf     # inputs
├── outputs.tf       # outputs
├── versions.tf      # required_providers (minimum versions)
└── README.md        # what it does, inputs, outputs, example
```

Larger modules may add `examples/` (runnable usage examples), `tests/`
(Chapter 19), and nested modules under `modules/`.

### A complete example

**`modules/secure-bucket/versions.tf`**

```hcl
terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 9.0"
    }
  }
}
```

A reusable module declares a **minimum** (and optionally a maximum) version,
not an exact pin — the root module chooses the exact version. Never put a
`provider "google" { ... }` *configuration* block in a reusable module; the
caller configures providers and the module inherits them.

**`modules/secure-bucket/variables.tf`**

```hcl
variable "project_id" {
  description = "Project in which to create the bucket."
  type        = string
}

variable "name" {
  description = "Globally unique bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$", var.name))
    error_message = "Bucket names must be 3-63 characters of lowercase letters, digits, dots, hyphens, or underscores."
  }
}

variable "location" {
  description = "Bucket location, e.g. EU or europe-west1."
  type        = string
  default     = "EU"
}

variable "retention_days" {
  description = "Delete objects older than this many days. 0 disables the rule."
  type        = number
  default     = 0
}

variable "readers" {
  description = "IAM members granted read access, e.g. user:ana@example.com."
  type        = set(string)
  default     = []
}

variable "labels" {
  description = "Labels added to the bucket."
  type        = map(string)
  default     = {}
}

variable "force_destroy" {
  description = "Allow deleting the bucket even if it contains objects."
  type        = bool
  default     = false
}
```

**`modules/secure-bucket/main.tf`**

```hcl
resource "google_storage_bucket" "this" {
  project                     = var.project_id
  name                        = var.name
  location                    = var.location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy
  labels                      = merge(var.labels, { managed_by = "terraform" })

  versioning {
    enabled = true
  }

  dynamic "lifecycle_rule" {
    for_each = var.retention_days > 0 ? [1] : []
    content {
      condition {
        age = var.retention_days
      }
      action {
        type = "Delete"
      }
    }
  }
}

resource "google_storage_bucket_iam_member" "readers" {
  for_each = var.readers

  bucket = google_storage_bucket.this.name
  role   = "roles/storage.objectViewer"
  member = each.value
}
```

Notice `this` as the resource name: a common convention when a module has one
main resource of a type.

> [!NOTE]
> **Google Cloud: managing IAM with Terraform.** For most resources the
> Google provider offers three kinds of IAM resource, here shown for buckets:
>
> | Resource | Manages | Other grants on the bucket |
> |---|---|---|
> | `google_storage_bucket_iam_member` | One principal in one role | Left alone |
> | `google_storage_bucket_iam_binding` | *All* principals of one role | Removed for that role |
> | `google_storage_bucket_iam_policy` | The whole policy | Removed |
>
> `_member` is *non-authoritative* and the safe default. `_binding` and
> `_policy` are *authoritative*: they make the real policy match your code,
> which silently removes grants that someone else, or Google, made. Never mix
> `_policy` with the other two for the same resource, and be very careful with
> the project-level `google_project_iam_policy`, which can lock you out of
> your own project. Principals are written with a prefix: `user:`, `group:`,
> `serviceAccount:`, `domain:`, or the special `allUsers` (anyone on the
> internet) and `allAuthenticatedUsers` (anyone with a Google account).

**`modules/secure-bucket/outputs.tf`**

```hcl
output "name" {
  description = "The bucket name."
  value       = google_storage_bucket.this.name
}

output "url" {
  description = "The gs:// URL of the bucket."
  value       = google_storage_bucket.this.url
}

output "self_link" {
  description = "The bucket's self link."
  value       = google_storage_bucket.this.self_link
}
```

### Calling it

```hcl
module "logs_bucket" {
  source = "./modules/secure-bucket"

  project_id     = var.project_id
  name           = "${var.project_id}-logs"
  retention_days = 30
  labels         = { purpose = "logs" }
}

output "logs_url" {
  value = module.logs_bucket.url
}
```

## 13.3 Variable scope `[5b]`

Each module has its **own namespace**. This is the most important rule about
modules and a favourite exam topic.

```
 root module                               child module "logs_bucket"
 ┌─────────────────────────────┐          ┌──────────────────────────────┐
 │ var.project_id              │  inputs  │ var.project_id               │
 │ var.environment             │ ───────▶ │ var.name                     │
 │ local.labels                │          │ var.retention_days           │
 │ google_compute_network.main │          │ google_storage_bucket.this   │
 │                             │ ◀─────── │                              │
 │ module.logs_bucket.url      │ outputs  │ output "url"                 │
 └─────────────────────────────┘          └──────────────────────────────┘
```

* A child module **cannot see** the parent's variables, locals, or resources.
  `var.environment` inside the child refers to the *child's* variable named
  `environment` — if it doesn't declare one, that's an error.
* The only way **in** is through the child's **input variables**, set as
  arguments in the `module` block.
* The only way **out** is through the child's **outputs**, read as
  `module.NAME.OUTPUT`.
* Locals are private to the module they're defined in.
* Sibling modules can't see each other; the parent wires them together by
  passing one module's output into another module's input.

```hcl
module "network" {
  source     = "./modules/network"
  project_id = var.project_id
}

module "web" {
  source     = "./modules/web-server"
  project_id = var.project_id
  subnet_id  = module.network.subnet_id   # wiring: output → input
}
```

This creates an implicit dependency: Terraform builds the network's subnet
before anything in the web module that uses `var.subnet_id`.

> **Exam tip:** "A child module needs a value from the root module — how?"
> → declare an input variable in the child and pass the value in the `module`
> block. "The root needs a value from a child module?" → the child declares an
> output; the root reads `module.NAME.OUTPUT`.

### Providers are the exception

Provider **configurations** are inherited: a child module automatically uses
the parent's default `google` provider. Use the `providers` argument to pass
a different (aliased) configuration explicitly (Chapter 12).

## 13.4 Designing good module interfaces

* **Small, focused modules** composed together beat one giant module with 80
  variables.
* **Sensible defaults** for everything that has a safe default; required
  inputs only for what the module can't guess (name, project).
* **Secure by default** — public access prevention, versioning, least
  privilege. Make insecure options explicit opt-ins.
* **Typed and validated inputs** — use `object()` with `optional()` and
  `validation` blocks.
* **Descriptions everywhere** — they become your documentation.
* **Output what callers need** — IDs, names, self links, URLs. Mark secrets
  `sensitive`.
* **Don't hard-code** projects, regions, or names.
* **No provider blocks**, minimum provider versions only.

### Documentation

Generate the inputs/outputs tables in your README automatically with the
popular open-source tool [terraform-docs](https://terraform-docs.io):

```console
$ terraform-docs markdown table ./modules/secure-bucket > ./modules/secure-bucket/README.md
```

## 13.5 Refactoring existing code into a module

You already have `google_storage_bucket.logs` in your root module and want to
switch to `module.logs_bucket`. The resource address changes from
`google_storage_bucket.logs` to `module.logs_bucket.google_storage_bucket.this`,
so Terraform would destroy and re-create the bucket. A `moved` block prevents
that (Chapter 11):

```hcl
moved {
  from = google_storage_bucket.logs
  to   = module.logs_bucket.google_storage_bucket.this
}
```

## 13.6 Versioning and publishing modules `[5d]`

Within a single repository, local paths (`./modules/...`) are simplest — the
module and its callers change together.

To share modules across repositories and teams, **version** them:

* **Git tags**: put the module in its own repository (or a monorepo
  sub-folder), tag releases (`v1.0.0`, `v1.1.0`), and call it with
  `?ref=v1.1.0`.
* **Public Terraform Registry**: the repository must be on GitHub, public,
  named `terraform-<PROVIDER>-<NAME>` (e.g. `terraform-google-secure-bucket`),
  have the standard structure, and use semantic-version tags. Each tag becomes
  a module version.
* **Private registry** in HCP Terraform (Chapter 17): the same, but only
  visible to your organisation.

Follow **semantic versioning**: `MAJOR.MINOR.PATCH`. Increase MAJOR for
breaking changes (renamed inputs, removed outputs, resources that would be
re-created), MINOR for new features, PATCH for bug fixes. Include `moved`
blocks when you rename things inside a module so callers can upgrade
without re-creation.

## Common mistakes and exam tips

* Referencing parent variables inside a child module — not possible; pass
  them in.
* Putting `provider` configuration blocks inside reusable modules.
* Pinning exact provider versions in reusable modules, making them hard to
  combine.
* Forgetting `terraform init` after adding a local module (yes, even local
  modules need `init`).
* Outputs are the module's public API; renaming one is a breaking change.

## Summary

* A module is a folder with `main.tf`, `variables.tf`, `outputs.tf`,
  `versions.tf`, and a README.
* Modules have their own scope: inputs in via variables, results out via
  outputs; parents wire siblings together.
* Reusable modules declare minimum provider versions and inherit provider
  configurations.
* Refactor into modules with `moved` blocks; share modules with Git tags or a
  registry, using semantic versioning.

## Quick check

1. Inside a child module, can you reference `local.labels` defined in the root
   module?
2. How does a root module pass a subnet ID from module A to module B?
3. Why shouldn't a reusable module contain a `provider "google"` block?
4. What naming convention must a module repository follow to be published on
   the public registry?
5. You move `google_storage_bucket.logs` into `module.logs`. What do you add
   to avoid re-creating it?

---

## Hands-on exercise: Your own secure-bucket module

**Goal:** Write a reusable module, call it several times, and refactor an
existing resource into it without re-creating it.

**Estimated time:** 30 minutes

**Files:** `code/ch13-writing-modules/exercise/`

### Steps

1. `cd code/ch13-writing-modules/exercise` and create `terraform.tfvars`.
2. **Start with plain resources.** `main.tf` contains a plain
   `google_storage_bucket.logs` resource. Run `terraform init` and
   `terraform apply` to create it.
3. **Write the module.** Complete the files in `modules/secure-bucket/`:
   * `variables.tf`: `project_id`, `name` (with validation), `location`
     (default `EU`), `retention_days` (default 0), `readers` (set of strings,
     default empty), `labels`, `force_destroy`.
   * `main.tf`: the bucket with uniform access, public access prevention,
     versioning, a dynamic lifecycle rule, and IAM members for readers.
   * `outputs.tf`: `name` and `url`.
   * `versions.tf`: minimum provider version.
4. **Refactor.** In the root `main.tf`, replace the `logs` resource with a
   `module "logs"` call (same bucket name, `retention_days = 30`) and add a
   `moved` block. Run `terraform init` (required for the new module) and
   `terraform plan`. The bucket must **not** be replaced — only updated in
   place (new settings like public access prevention).
5. **Reuse.** Add a second module call `module "reports"` using `for_each`
   over `toset(["finance", "marketing"])` to create two more buckets. Run
   `terraform init` again: every new `module` block needs it, even when it
   uses the same source as an existing one. Otherwise `plan` fails with
   "Module not installed".
6. **Scope experiment.** Inside `modules/secure-bucket/main.tf`, try using
   `var.environment` (which only exists in the root). Run
   `terraform validate` and read the error. Remove it again.
7. In the root `outputs.tf`, output all bucket URLs: the logs bucket and a
   map of the reports buckets.
8. Apply and run `terraform state list`.

### Expected result

Three buckets created by one module, the original `logs` bucket preserved
through the refactoring.

### Stretch goal

Install terraform-docs and generate the module's README.

### Cleanup

```console
$ terraform destroy
```

---

## Quick check answers

1. No. Child modules can't see the parent's locals, variables, or resources.
2. Module A declares an output; the root passes `module.a.subnet_id` as an
   input argument to module B.
3. Provider configuration belongs to the root module; a provider block in a
   module prevents callers from controlling configuration (and blocks
   `count`/`for_each` on the module). Modules inherit providers instead.
4. `terraform-<PROVIDER>-<NAME>`, e.g. `terraform-google-secure-bucket`.
5. A `moved` block from `google_storage_bucket.logs` to
   `module.logs.google_storage_bucket.this`.
