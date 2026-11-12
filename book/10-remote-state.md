# Chapter 10 — Remote State on Google Cloud Storage

## Learning objectives

By the end of this lesson you will be able to:

* Explain why teams use **remote state** and what a backend provides. `[6c]`
* Create a secure Cloud Storage bucket for Terraform state.
* Configure the `gcs` backend with the `backend` block. `[6c]`
* **Migrate** existing local state to a remote backend. `[6c]`
* Use **partial backend configuration** to keep environment-specific
  settings out of code. `[6c]`
* Read another configuration's outputs with the `terraform_remote_state`
  data source. `[6c]`

**Time:** about 1 hour — 20 reading, 5 quick check, 35 exercise.

---

## 10.1 Why remote state? `[6c]`

Chapter 9 listed the weaknesses of the local backend: state lives on one
laptop, there's no shared locking, and no access control. A **remote backend**
stores state in a shared, durable service instead.

| Need | Local backend | Remote backend (e.g. GCS) |
|---|---|---|
| Team members share state | ✗ | ✓ |
| Locking across machines | ✗ | ✓ |
| Durable (survives a lost laptop) | ✗ | ✓ |
| Encrypted at rest, IAM access control | ✗ | ✓ |
| Version history of state | manual backups | ✓ (bucket versioning) |
| Works in CI/CD pipelines | ✗ | ✓ |

Terraform includes many backends: `gcs` (Google Cloud Storage), `s3` (AWS),
`azurerm` (Azure), `consul`, `pg` (PostgreSQL), `http`, `kubernetes`, and
more. HCP Terraform (Chapter 16) is also a remote state store, configured
with the `cloud` block instead of `backend`.

With the `gcs` backend, state is stored as an object in a bucket and Terraform
automatically creates a **lock object** next to it during operations, so
locking works out of the box.

## 10.2 The chicken-and-egg problem

The state bucket must exist before Terraform can store state in it. Who
creates the bucket? Common solutions:

1. Create it once with `gcloud` (simple and common).
2. Create it with a small, separate **bootstrap** Terraform configuration that
   uses local state (or later migrates its own state into the bucket).

We use option 2, because it's code and it shows the migration process.

### A secure state bucket

```hcl
resource "google_storage_bucket" "tfstate" {
  name     = "${var.project_id}-tfstate"
  location = "EU"

  # Keep old versions of the state so mistakes can be undone.
  versioning {
    enabled = true
  }

  # Clean up very old non-current versions.
  lifecycle_rule {
    condition {
      num_newer_versions = 20
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # Protect against accidental deletion.
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}
```

Security checklist for a state bucket:

* **Versioning** on — each state write creates a new object version, so you
  can restore an earlier one.
* **Uniform bucket-level access** and **public access prevention** — no
  accidental public exposure.
* **Least-privilege IAM** — only the people and service accounts who run
  Terraform get `roles/storage.objectAdmin` on this bucket.
* Data is **encrypted at rest** by default. For extra control use a
  customer-managed encryption key (`encryption { default_kms_key_name = ... }`)
  or the backend's `kms_encryption_key` setting.
* A separate project (or at least a separate bucket) per environment
  (Chapter 18).

> [!NOTE]
> **Google Cloud: object versioning, lifecycle rules, and public access
> prevention.** With **object versioning**, overwriting or deleting an object
> doesn't destroy the old data: the previous content is kept as a
> *noncurrent* version (`ARCHIVED` in Terraform's `with_state`), which you
> can list with `gcloud storage ls --all-versions gs://BUCKET/PATH` and
> restore. Noncurrent versions are billed like normal data, so a **lifecycle
> rule** deletes them automatically; lifecycle rules can also delete objects
> or move them to a cheaper storage class after a number of days. **Public
> access prevention** set to `enforced` blocks every grant to `allUsers` or
> `allAuthenticatedUsers`, so the bucket can't be made public even by mistake.

## 10.3 Configuring the `gcs` backend `[6c]`

Add a `backend` block inside the `terraform` block:

```hcl
terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }

  backend "gcs" {
    bucket = "tf-book-fatih-12345-tfstate"
    prefix = "ch10/app"
  }
}
```

* `bucket` — the state bucket.
* `prefix` — a "folder" inside the bucket. The state is stored at
  `<prefix>/default.tfstate` (`default` is the workspace name; Chapter 18).
  Use a different prefix for every configuration that shares the bucket.

The backend uses the same Application Default Credentials as the provider.

### Backend blocks can't use variables

The backend is initialised **before** variables are evaluated, so this does
**not** work:

```hcl
backend "gcs" {
  bucket = var.state_bucket   # Error: Variables may not be used here.
}
```

Use **partial configuration** instead (10.5).

## 10.4 Migrating local state to GCS `[6c]`

Suppose you've been working with local state and now add the `backend` block.
Run `init` again:

```console
$ terraform init
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "gcs" backend. No existing state was found in the newly
  configured "gcs" backend. Do you want to copy this state to the new "gcs"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value: yes

Successfully configured the backend "gcs"! Terraform will automatically
use this backend unless the backend configuration changes.
```

Terraform copies the state to the bucket. Afterwards:

* `terraform plan` should show **no changes** — same state, new location.
* The local `terraform.tfstate` is left behind, empty or stale. Delete it to
  avoid confusion (keep a copy until you've confirmed everything works).
* `.terraform/terraform.tfstate` now records the backend configuration (not
  your infrastructure state).

Useful `init` flags:

| Flag | Meaning |
|---|---|
| `-migrate-state` | Copy state to the newly configured backend (prompts for confirmation). |
| `-reconfigure` | Use the new backend configuration *without* migrating state. |
| `-backend=false` | Skip backend initialisation (e.g. for `validate` in CI). |
| `-backend-config=...` | Supply backend settings (partial configuration). |
| `-force-copy` | Answer "yes" to migration prompts (automation). |

To move back to local state, remove the `backend` block and run
`terraform init -migrate-state`.

## 10.5 Partial backend configuration `[6c]`

Hard-coding the bucket name is a problem when the same code is deployed to
different environments with different state buckets. Leave settings out of
the `backend` block and supply them at `init` time:

```hcl
terraform {
  backend "gcs" {}
}
```

```hcl
# backend-dev.hcl
bucket = "acme-dev-tfstate"
prefix = "network"
```

```console
$ terraform init -backend-config=backend-dev.hcl
```

or individual key/value pairs:

```console
$ terraform init -backend-config="bucket=acme-dev-tfstate" -backend-config="prefix=network"
```

This is the standard technique for multiple environments and CI/CD
(Chapters 18 – 21).

> **Security tip:** Don't put credentials into backend configuration files.
> The `gcs` backend picks up ADC or Workload Identity Federation credentials
> automatically.

## 10.6 Sharing data: `terraform_remote_state` `[6c]`

Large systems are split into several configurations — for example a
**network** configuration owned by the platform team and an **app**
configuration owned by developers. The app needs the network's subnet ID.

The `terraform_remote_state` data source reads the **outputs** of another
configuration's state:

```hcl
data "terraform_remote_state" "network" {
  backend = "gcs"

  config = {
    bucket = "tf-book-fatih-12345-tfstate"
    prefix = "ch10/network"
  }
}

resource "google_compute_instance" "app" {
  # ...
  network_interface {
    subnetwork = data.terraform_remote_state.network.outputs.subnet_id
  }
}
```

* Only **root-module outputs** are accessible (`.outputs.<name>`), not
  resources.

### Sharing a value that comes from a module

Often the value you want lives inside a **module** in the other
configuration — for example, the network configuration calls a `network`
module (Chapter 12) that outputs `subnet_id`. A module's outputs belong to
the module, not to the configuration, so they are **not** written to the
state's outputs on their own. The producing configuration has to re-export
the value as a root output:

```hcl
# network/main.tf (producer)
module "network" {
  source = "./modules/network"
  # ...
}

# network/outputs.tf (producer): pass the module output through
output "subnet_id" {
  value = module.network.subnet_id
}
```

Only then can the consumer read it:

```hcl
# app/main.tf (consumer)
subnetwork = data.terraform_remote_state.network.outputs.subnet_id
```

The chain is always **module output → root output → remote state**.
`data.terraform_remote_state.network.outputs.module.network.subnet_id`
doesn't exist; if you forget the root output, the consumer fails with
*"This object does not have an attribute named "subnet_id""*. After adding
the root output, run `terraform apply` in the producer: outputs are saved to
state only by an apply.

> **Exam tip:** A child module's outputs are visible only to its parent
> module. To expose them to the CLI, to `terraform_remote_state`, or to
> `tfe_outputs`, declare them again as `output` blocks in the root module.

More about the remote state data source:

* The reader needs read access to the whole state file, which may contain
  secrets. For this reason, many teams prefer to look up shared
  infrastructure with ordinary **data sources** (e.g.
  `data "google_compute_subnetwork"` by name) or publish values to a
  configuration store, instead of granting state access.
* In HCP Terraform, the `tfe_outputs` data source is a safer alternative that
  exposes only outputs.

> **Exam tip:** `terraform_remote_state` exposes only the **root module
> outputs** of the other configuration, and it's read-only.

## 10.7 Backend vs. state — keep them straight

* The **backend** decides *where* state is stored (and how it's locked).
* **State** is the content.
* Changing the backend never changes your infrastructure; it only moves the
  state.
* Backend configuration isn't stored in the state file; it's stored in
  `.terraform/` and in your code.

## Common mistakes and exam tips

* Using variables in a `backend` block → error. Use partial configuration.
* Forgetting to re-run `terraform init` after changing the backend → error
  "Backend initialization required".
* Two configurations sharing the same bucket **and prefix** → they overwrite
  each other's state.
* Not enabling versioning on the state bucket.
* `terraform_remote_state` needs only outputs, but grants access to the
  whole state.

## Summary

* Remote backends provide shared, locked, durable, access-controlled state.
* The `gcs` backend stores state in a Cloud Storage bucket with automatic
  locking; secure the bucket with versioning, uniform access, public access
  prevention, and least-privilege IAM.
* `terraform init` migrates state when the backend changes.
* Partial configuration (`-backend-config`) supplies backend settings at
  init time.
* `terraform_remote_state` reads another configuration's root outputs.

## Quick check

1. Why can't you write `bucket = var.state_bucket` in a backend block?
2. What command migrates existing local state to a newly configured backend?
3. Where in the bucket does the `gcs` backend store state for
   `prefix = "network"` in the default workspace?
4. What does `terraform_remote_state` give you access to?
5. Name three settings that make a state bucket more secure.

---

## Hands-on exercise: Move to remote state and share outputs

**Goal:** Create a secure state bucket, migrate a configuration's local state
into it, and read its outputs from a second configuration.

**Estimated time:** 35 minutes

**Files:** `code/ch10-remote-state/exercise/` with three sub-folders:
`bootstrap/`, `network/`, and `app/`.

### Steps

1. **Bootstrap.** In `bootstrap/`, create `terraform.tfvars` and complete the
   `TODO`s to create a versioned state bucket with uniform access and public
   access prevention. Apply. Note the `state_bucket` output.
2. **Network with local state.** In `network/`, create `terraform.tfvars`,
   `terraform init`, and `terraform apply`. A `terraform.tfstate` file
   appears locally.
3. **Migrate.** Complete the `TODO` in `network/versions.tf`: add an *empty*
   `backend "gcs" {}` block. Copy `backend.hcl.example` to `backend.hcl` and
   fill in the bucket name. Run:

   ```console
   $ terraform init -migrate-state -backend-config=backend.hcl
   ```

   Answer `yes`. Run `terraform plan` (no changes), then delete the local
   `terraform.tfstate` and `terraform.tfstate.backup`.
4. Find the state in the bucket:
   `gcloud storage ls -r gs://<state-bucket>/`. Run `terraform plan` again
   and, while it runs, list the bucket again to spot the `.tflock` file.
5. **Prove that versioning works:** in `network/main.tf`, add
   `private_ip_google_access = true` to the subnet (an in-place update),
   apply, and list object versions with
   `gcloud storage ls -a gs://<state-bucket>/ch10/network/`. Every apply
   adds a `default.tfstate#<generation>` version. You'll also see old
   versions of `default.tflock`, because the bucket keeps those too.
6. **App.** In `app/`, configure the `gcs` backend with prefix `ch10/app`
   (via `backend.hcl`). Complete the `terraform_remote_state` data source to
   read the network's outputs, and use `subnet_id` for the VM. Apply.
7. **Module output.** `network/main.tf` also calls a small module,
   `modules/iap-ssh`, that creates a firewall rule allowing SSH through
   Identity-Aware Proxy to VMs carrying a network tag. The module outputs
   that tag as `target_tag`. The app VM should carry it.
   1. In `app/main.tf`, complete the `TODO`:
      `tags = [data.terraform_remote_state.network.outputs.ssh_tag]`. Run
      `terraform plan` in `app/`. It fails:

      ```text
      Error: Unsupported attribute
      ...
      This object does not have an attribute named "ssh_tag".
      ```

      The module's output is only visible inside the network configuration
      (as `module.iap_ssh.target_tag`), not in its state's root outputs.
   2. In `network/outputs.tf`, complete the `TODO`: add a root output
      `ssh_tag` with `value = module.iap_ssh.target_tag`. Run
      `terraform apply` in `network/`. The plan changes no resources (the
      module's firewall rule has existed since step 2) and shows only the
      new output under "Changes to Outputs".
   3. Run `terraform plan` in `app/` again. It now shows the VM's `tags`
      changing in place. Apply, then check the tag:

      ```console
      $ gcloud compute instances describe ch10-app --zone=europe-west1-b --format="value(tags.items)"
      ```
8. Run `terraform state list` in `app/`. Is the subnet listed? Why not?

### Expected result

Two configurations whose states live in your bucket under `ch10/network/` and
`ch10/app/`. The app consumes the network's outputs, including `ssh_tag`,
which a module produces and the network configuration re-exports as a root
output.

### Stretch goal

Replace `terraform_remote_state` in `app/` with a
`data "google_compute_subnetwork"` lookup by name and region. Which approach
do you prefer, and why?

### Challenge

*Optional, about 30 minutes. There are no starter files and no `TODO`s: work
in a new, empty folder from the requirements alone. Do this before the
exercise's cleanup: it needs the applied `network/` configuration. A reference
solution is in `code/ch10-remote-state/challenge/storage/`.*

Add a third configuration, `storage/`, next to `network/` and `app/`.

* Its state lives in your state bucket under the prefix `ch10/storage`. The
  bucket name must not appear in any `.tf` file.
* It creates one regional bucket in **the same region as the network
  configuration's subnet**, and it finds that region by reading the network
  configuration's state. No region may be hard-coded.
* Outputs: the bucket's name and location.

Then move this configuration's state to the prefix `ch10/files`, without
re-creating the bucket.

**Done when** `terraform plan` shows no changes after the move, and you can
answer: what happened to the state object under the old prefix? What would
`terraform init -reconfigure` have done instead?

### Cleanup

Destroy in reverse order:

```console
$ (cd app && terraform destroy)
$ (cd network && terraform destroy)
```

Keep the state bucket — you'll reuse it in later chapters. (If you want to
delete it: remove `prevent_destroy`, set `force_destroy = true`, apply, then
destroy in `bootstrap/`.)

---

## Quick check answers

1. Backend configuration is processed during `init`, before variables are
   evaluated. Use partial configuration with `-backend-config`.
2. `terraform init -migrate-state` (plain `terraform init` also prompts).
3. `network/default.tfstate`.
4. The root-module output values of another configuration's state.
5. Any three: versioning, uniform bucket-level access, public access
   prevention, least-privilege IAM, CMEK encryption, `prevent_destroy`.
