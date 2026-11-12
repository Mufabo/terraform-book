# Chapter 11 — Drift, Import, and Refactoring

## Learning objectives

By the end of this lesson you will be able to:

* Explain **resource drift** and detect it with `-refresh-only`. `[6d]`
* Choose how to resolve drift: revert, accept, or ignore. `[6d]`
* Force replacement of a resource with `-replace`. `[6d]`
* **Import** existing infrastructure with `import` blocks and generate
  configuration automatically. `[7a]`
* Refactor safely with `moved` and `removed` blocks. `[6d]`

---

## 11.1 What is drift? `[6d]`

**Drift** happens when real infrastructure no longer matches what Terraform
recorded in state — usually because someone changed it *outside* Terraform:

* A colleague edits a firewall rule in the console during an incident.
* An automated tool adds labels to VMs.
* A resource is deleted manually.

Terraform discovers drift during the **refresh** step of every plan. Look for
this section in plan output:

```
Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the
last "terraform apply" which may have affected this plan:

  # google_storage_bucket.site has changed
  ~ resource "google_storage_bucket" "site" {
        id     = "tf-book-fatih-12345-ch11-site"
      ~ labels = {
          ~ "team" = "web" -> "marketing"
        }
    }
```

followed by the plan to *undo* that change, because the configuration still
says `team = "web"`:

```
  # google_storage_bucket.site will be updated in-place
  ~ resource "google_storage_bucket" "site" {
      ~ labels = {
          ~ "team" = "marketing" -> "web"
        }
    }
```

(The real output also lists `effective_labels` and `terraform_labels`; see
Chapter 3.) As Chapter 8 showed, the Google provider only compares the labels
in your configuration. A label that someone *adds* outside Terraform appears
only under `effective_labels` in the drift note, and the plan doesn't undo it.

## 11.2 Detecting drift without changing anything: `-refresh-only`

A **refresh-only** plan shows *only* the drift, not any configuration
changes:

```console
$ terraform plan -refresh-only
```

And a refresh-only apply **updates the state** to match reality, without
touching any infrastructure:

```console
$ terraform apply -refresh-only
...
Would you like to update the Terraform state to reflect these detected changes?
  Enter a value: yes
```

This replaces the old `terraform refresh` command, which did the same thing
without showing you what changes or asking for confirmation.

> **Exam tip:** `terraform plan -refresh-only` = "show me drift".
> `terraform apply -refresh-only` = "accept drift into the state". Neither
> changes real resources.

## 11.3 Resolving drift `[6d]`

You have three choices:

| Choice | How | When |
|---|---|---|
| **Revert** the manual change | `terraform apply` — Terraform restores the configured values | The manual change was a mistake or a temporary fix. |
| **Accept** the manual change | Update the `.tf` code to match, then plan (no changes) | The change was correct and should be kept. |
| **Ignore** the attribute | `lifecycle { ignore_changes = [...] }` (Chapter 8) | Another system legitimately owns that attribute. |

If a resource was **deleted** outside Terraform, the refresh removes it from
state and the plan proposes to create it again.

Prevent drift in the first place: restrict console write access, route all
changes through code review and CI/CD, and run scheduled drift detection
(HCP Terraform does this for you; Chapter 17).

## 11.4 Forcing replacement: `-replace` `[6d]`

Sometimes an object is "broken" in a way Terraform can't see — a VM whose
disk is corrupted, or whose startup script failed. You want Terraform to
destroy and re-create it, even though nothing changed in code:

```console
$ terraform plan -replace="google_compute_instance.web"
  # google_compute_instance.web will be replaced, as requested
-/+ resource "google_compute_instance" "web" {
...
$ terraform apply -replace="google_compute_instance.web"
```

The older `terraform taint` command marked a resource for replacement in
state. It's **deprecated**; use `-replace` instead, because it shows the
effect in a plan before anything happens.

## 11.5 Importing existing infrastructure `[7a]`

Many organisations start using Terraform after building things by hand. To
bring an existing resource under Terraform management, you **import** it:
Terraform reads the real object and records it in state, linked to a resource
address in your configuration.

### The `import` block (recommended)

```hcl
import {
  to = google_storage_bucket.legacy
  id = "tf-book-fatih-12345-legacy"
}

resource "google_storage_bucket" "legacy" {
  name     = "tf-book-fatih-12345-legacy"
  location = "EU"
}
```

* `to` — the resource address the object should be linked to.
* `id` — the provider-specific **import ID**. Each resource's documentation
  page has an "Import" section listing the accepted formats. For a bucket
  it's the name; for a network it's
  `projects/{project}/global/networks/{name}`.

> [!NOTE]
> **Google Cloud: resource names.** Most Google Cloud resources have a full
> name that shows where they live:
>
> ```
> projects/tf-book-fatih-12345/global/networks/default                  # global
> projects/tf-book-fatih-12345/regions/europe-west1/subnetworks/app     # regional
> projects/tf-book-fatih-12345/zones/europe-west1-b/instances/web       # zonal
> ```
>
> The Google provider usually stores this path as the resource's `id`, which
> is why it's also the import ID. A **self link** is the same path as a full
> API URL (`https://www.googleapis.com/compute/v1/projects/...`). Some
> resources are known by a short name only (buckets, which are global and
> unique) or by the project *number* rather than the ID. When in doubt, check
> the import section of the resource's documentation page, or read the name
> with `gcloud ... describe`.

Run a plan:

```console
$ terraform plan
google_storage_bucket.legacy: Preparing import... [id=tf-book-fatih-12345-legacy]
google_storage_bucket.legacy: Refreshing state... [id=tf-book-fatih-12345-legacy]

  # google_storage_bucket.legacy will be imported
    resource "google_storage_bucket" "legacy" {
        ...
    }

Plan: 1 to import, 0 to add, 0 to change, 0 to destroy.
```

If the plan also shows **changes** for the imported resource, your
configuration doesn't match reality yet. Adjust the code until the plan shows
only the import, then apply:

```console
$ terraform apply
Apply complete! Resources: 1 imported, 0 added, 0 changed, 0 destroyed.
```

After a successful import, you can delete the `import` block (or keep it as
a record; it does nothing once the resource is in state).

Benefits of import blocks over the old command:

* Imports are **planned** and reviewed like any other change.
* Many imports can happen in one apply.
* They work in CI/CD and HCP Terraform.

### Generating configuration automatically

Writing the matching resource block by hand is tedious. Let Terraform write
it for you: create *only* the `import` block, then run

```console
$ terraform plan -generate-config-out=generated.tf
```

Terraform writes a `generated.tf` file with a resource block containing every
attribute it read. Review it carefully — it includes many default values and
sometimes conflicting arguments that you need to tidy up — then move it into
your normal files.

### Importing many objects with `for_each`

```hcl
locals {
  legacy_buckets = {
    images = "acme-legacy-images"
    videos = "acme-legacy-videos"
  }
}

import {
  for_each = local.legacy_buckets
  to       = google_storage_bucket.legacy[each.key]
  id       = each.value
}

resource "google_storage_bucket" "legacy" {
  for_each = local.legacy_buckets
  name     = each.value
  location = "EU"
}
```

### The `terraform import` command (legacy)

```console
$ terraform import google_storage_bucket.legacy tf-book-fatih-12345-legacy
```

This immediately writes to state without a plan, imports one resource at a
time, and requires that the resource block already exists. It still works and
appears in older documentation and exam questions.

> **Exam tip:** Know both. The `import` block is declarative and planned;
> `terraform import ADDRESS ID` is imperative and immediate. Neither writes
> the final configuration for you unless you use `-generate-config-out`
> (import blocks only). Import never creates resources.

> **Newer than the exam:** Terraform 1.14 introduced `terraform query` and
> `list` blocks that can *search* a provider for existing resources and
> produce import blocks in bulk, if the provider supports it.

## 11.6 Refactoring with `moved` blocks `[6d]`

Code evolves: you rename resources, convert a single resource into a
`for_each`, or move resources into a module. Each of these changes the
**resource address**, and by default Terraform would destroy the object at
the old address and create a new one at the new address.

Chapter 9 showed `terraform state mv`. The declarative way is a `moved`
block:

```hcl
# Renamed from "notes" to "docs"
moved {
  from = google_storage_bucket.notes
  to   = google_storage_bucket.docs
}

resource "google_storage_bucket" "docs" {
  name     = "tf-book-fatih-12345-notes"
  location = "EU"
}
```

```console
$ terraform plan
  # google_storage_bucket.notes has moved to google_storage_bucket.docs
    resource "google_storage_bucket" "docs" {
        id   = "tf-book-fatih-12345-notes"
        name = "tf-book-fatih-12345-notes"
        ...
    }

Plan: 0 to add, 0 to change, 0 to destroy.
```

More examples:

```hcl
# Single resource -> for_each instance
moved {
  from = google_storage_bucket.logs
  to   = google_storage_bucket.this["logs"]
}

# count -> for_each
moved {
  from = google_compute_instance.web[0]
  to   = google_compute_instance.web["blue"]
}

# Resource -> into a module (Chapter 13)
moved {
  from = google_compute_network.main
  to   = module.network.google_compute_network.this
}
```

Why `moved` is better than `state mv`:

* It's code: reviewed in a pull request, applied in CI.
* Everyone who applies the configuration (every environment, every teammate)
  gets the move automatically.
* Module authors can ship `moved` blocks so module users upgrade safely.

Keep `moved` blocks for a while (until every environment has applied them);
removing them later is harmless once all states are updated.

## 11.7 Stop managing without destroying: `removed` blocks

To remove a resource from Terraform *without destroying* the real object,
delete the resource block and add a `removed` block:

```hcl
removed {
  from = google_storage_bucket.handover

  lifecycle {
    destroy = false
  }
}
```

```console
$ terraform plan
  # google_storage_bucket.handover will no longer be managed by Terraform
...
Plan: 0 to add, 0 to change, 0 to destroy.
```

After applying, the bucket still exists but isn't in state anymore. This is
the declarative equivalent of `terraform state rm`. With `destroy = true`,
the block simply documents an intentional deletion.

## 11.8 Summary table

| Goal | Declarative (preferred) | Imperative (legacy) |
|---|---|---|
| Rename / move a resource | `moved` block | `terraform state mv` |
| Stop managing (keep object) | `removed` block with `destroy = false` | `terraform state rm` |
| Adopt an existing object | `import` block | `terraform import` |
| Re-create an object | `-replace=ADDRESS` | `terraform taint` (deprecated) |
| Accept drift into state | `apply -refresh-only` | `terraform refresh` (deprecated) |

## Common mistakes and exam tips

* Expecting import to write configuration for you (only with
  `-generate-config-out`).
* Applying an import while the plan still shows changes — you'd modify the
  real resource.
* Renaming a resource without `moved` → destroy and re-create.
* Deleting a resource block to "unmanage" it → Terraform destroys it. Use
  `removed`.
* `taint` and `refresh` are deprecated, but you may still see them in exam
  questions.

## Summary

* Drift is a difference between real infrastructure and state; `-refresh-only`
  shows and accepts it.
* Resolve drift by reverting (apply), accepting (update code), or ignoring
  (`ignore_changes`).
* `-replace` forces re-creation.
* `import` blocks (optionally with `-generate-config-out`) adopt existing
  resources through the normal plan/apply workflow.
* `moved` and `removed` blocks refactor state declaratively.

## Quick check

1. Which command shows drift without proposing any configuration changes?
2. Someone deleted a bucket manually. What will the next `terraform plan`
   propose?
3. What two arguments does an `import` block require?
4. You converted `google_storage_bucket.logs` into
   `google_storage_bucket.this["logs"]`. How do you avoid re-creating it?
5. How do you stop managing a resource without destroying it, declaratively?

---

## Hands-on exercise: Adopt, drift, and refactor

**Goal:** Import manually created resources, detect and resolve drift, and
refactor with `moved` and `removed` blocks.

**Estimated time:** 30 minutes

**Files:** `code/ch11-drift-import/exercise/`

### Steps

1. **Create "legacy" resources by hand.** Run the provided script, which uses
   `gcloud` to create two buckets outside Terraform:

   ```console
   $ cd code/ch11-drift-import/exercise
   $ ./create-legacy.sh <your-project-id>
   ```

2. **Import with generated configuration.** Create `terraform.tfvars`. In
   `imports.tf`, uncomment and complete the `import` block for the `...-legacy-site` bucket,
   targeting `google_storage_bucket.site`. Do *not* write the resource block.
   Run `terraform init` and:

   ```console
   $ terraform plan -generate-config-out=generated.tf
   ```

   Open `generated.tf` and move its resource block to `main.tf`. Tidy it up:
   keep `name`, `location`, `storage_class`, `uniform_bucket_level_access`,
   and set `force_destroy = true`; delete attributes that are only defaults.
   The generated `labels = {}` is empty because the provider only lists
   labels that Terraform manages; write `labels = { team = "web" }` to take
   over the bucket's existing label. In `token.tf`, you can now use
   `google_storage_bucket.site.name`. Plan again until it shows
   `1 to import, 2 to add, 1 to change`. The two additions are the token from
   `token.tf`. The one change is the imported bucket: `force_destroy` is a
   Terraform-only setting that import always records as `false`, and `team`
   moves into `labels`. Neither changes the real bucket. Apply.
3. **Legacy import command.** Write a resource block
   `google_storage_bucket.media` for the `...-legacy-media` bucket yourself,
   then import it with
   `terraform import google_storage_bucket.media <project-id>-legacy-media`.
   Run `terraform plan` and fix differences until the only change left is
   `force_destroy = false -> true` (Terraform-only, as in step 2). Apply it;
   the next plan shows no changes.
4. **Drift.** Change the site bucket's `team` label behind Terraform's back:

   ```console
   $ gcloud storage buckets update gs://<project-id>-legacy-site --update-labels=team=marketing
   ```

   Run `terraform plan -refresh-only` (it shows `"web" -> "marketing"`), then
   `terraform plan` (it proposes to change it back). Decide to *accept* the
   change: set `team = "marketing"` in the code and plan again (no changes).
5. **Replace.** Run `terraform plan -replace=random_id.token` and then apply
   it. Which other resources changed?
6. **Moved.** Rename `google_storage_bucket.media` to
   `google_storage_bucket.assets` and add a `moved` block. Plan: no destroy.
   Apply.
7. **Removed.** Delete the `google_storage_bucket.assets` block and add a
   `removed` block with `destroy = false`. Apply. Confirm the bucket still
   exists with `gcloud storage ls`.

### Expected result

Both legacy buckets were adopted without recreation; you accepted drift,
renamed a resource, and released one bucket from management.

### Stretch goal

Import the `default` VPC network of your project
(`projects/<project-id>/global/networks/default`) with an import block and
generated configuration. Then remove it again with a `removed` block
(`destroy = false`) — you don't want Terraform to manage it.

### Cleanup

```console
$ terraform destroy
$ gcloud storage rm -r gs://<project-id>-legacy-media   # released in step 7
```

---

## Quick check answers

1. `terraform plan -refresh-only`.
2. To create the bucket again (refresh removes it from state; the
   configuration still declares it).
3. `to` (the resource address) and `id` (the provider-specific import ID).
4. Add a `moved` block from `google_storage_bucket.logs` to
   `google_storage_bucket.this["logs"]` (or run `terraform state mv`).
5. Replace the resource block with a `removed` block containing
   `lifecycle { destroy = false }`.
