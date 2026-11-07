# Chapter 18 — Managing Multiple Environments

## Learning objectives

By the end of this lesson you will be able to:

* Explain why teams separate **dev**, **staging**, and **production** and
  what "isolation" means for infrastructure.
* Use **CLI workspaces** and `terraform.workspace`, and explain their limits.
* Compare three strategies: CLI workspaces, tfvars-per-environment, and
  **directory-per-environment with shared modules**.
* Build a recommended repository layout for multiple environments on Google
  Cloud, with separate state per environment.
* Promote changes safely from dev to prod.

---

## 18.1 Why multiple environments?

Changing production directly is risky. Most teams run several copies of
their infrastructure:

| Environment | Purpose | Typical size |
|---|---|---|
| **dev** | Developers try changes; may break. | Small, cheap |
| **staging** (or *test*, *qa*) | Production-like rehearsal of releases. | Similar to prod, smaller |
| **prod** | Real users. | Full size, high availability, protected |

The environments should be **as similar as possible** (so testing in staging
means something) but **isolated** (so a mistake in dev can't hurt prod).

### Isolation on Google Cloud

The strongest, simplest isolation boundary on Google Cloud is the **project**:

```
Organization / Folder "web-shop"
├── project acme-webshop-dev
├── project acme-webshop-staging
└── project acme-webshop-prod
```

Separate projects give each environment its own IAM, quotas, billing
reports, APIs, and blast radius. Combine this with:

* **Separate state** per environment (different bucket or at least different
  prefix) so a `destroy` in dev can never touch prod state.
* **Separate identities**: the dev pipeline's service account has no
  permissions in the prod project.
* **Different approval rules**: dev applies automatically; prod requires a
  human approval (Chapters 21 and 22).

> In this book you have a single learning project, so the exercise
> simulates environments with name prefixes. The structure is identical to
> the real thing — just change `project_id` per environment.

## 18.2 Strategy 1: CLI workspaces

The Terraform CLI can keep **several states for one configuration** in the
same backend, called **workspaces**. You start in the `default` workspace.

```console
$ terraform workspace list
* default

$ terraform workspace new dev
Created and switched to workspace "dev"!

$ terraform workspace new prod
$ terraform workspace select dev
$ terraform workspace show
dev
```

Each workspace has its own state. With the `gcs` backend, they're stored as
`<prefix>/dev.tfstate`, `<prefix>/prod.tfstate`, and so on (the local backend
uses `terraform.tfstate.d/<name>/`).

In the configuration, `terraform.workspace` holds the current workspace's
name:

```hcl
locals {
  env = terraform.workspace

  machine_type = {
    dev  = "e2-micro"
    prod = "e2-standard-2"
  }
}

resource "google_compute_instance" "web" {
  name         = "${local.env}-web"
  machine_type = local.machine_type[local.env]
  # ...
}
```

**Pros:** one copy of the code, quick to set up, good for short-lived copies
(e.g. a temporary environment per feature branch).

**Cons:**

* All environments share **one backend** (same bucket, same credentials) —
  weak isolation.
* The current workspace is invisible in the code; it's easy to apply to the
  wrong one. (Always check `terraform workspace show`!)
* Differences between environments hide in maps and conditionals.
* Every environment must use the same code version at the same time — no
  gradual promotion.

> **Exam tip:** `terraform workspace new|select|list|show|delete`,
> `terraform.workspace`, and the fact that each CLI workspace has a separate
> state in the same backend are all fair game. You can't delete the `default`
> workspace.

## 18.3 Strategy 2: one configuration, a tfvars file per environment

```
infra/
├── main.tf
├── variables.tf
├── dev.tfvars
├── prod.tfvars
├── backend-dev.hcl
└── backend-prod.hcl
```

```console
$ terraform init -reconfigure -backend-config=backend-dev.hcl
$ terraform apply -var-file=dev.tfvars
```

Differences live in explicit tfvars files, and each environment can use its
own state bucket via partial backend configuration (Chapter 10). But it's
easy to combine the wrong backend with the wrong tfvars, and you still can't
roll out code changes to dev before prod.

## 18.4 Strategy 3: a directory per environment + shared modules (recommended)

```
infra/
├── modules/
│   └── web-app/              ← the reusable building block (Chapter 13)
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── versions.tf
└── envs/
    ├── dev/
    │   ├── main.tf           ← calls ../../modules/web-app with dev values
    │   ├── versions.tf       ← provider pins + backend "gcs" (prefix envs/dev)
    │   ├── terraform.tfvars  ← dev project ID etc.
    │   └── .terraform.lock.hcl
    ├── staging/
    └── prod/
```

Each environment is its own **root module** with its own state, backend
settings, provider configuration, and variables. The shared logic lives in
modules.

`envs/dev/main.tf`:

```hcl
module "web_app" {
  source = "../../modules/web-app"

  project_id    = var.project_id
  region        = var.region
  environment   = "dev"
  min_instances = 0
  max_instances = 2
  public        = true
}
```

`envs/prod/main.tf`:

```hcl
module "web_app" {
  source = "../../modules/web-app"

  project_id    = var.project_id
  region        = var.region
  environment   = "prod"
  min_instances = 1
  max_instances = 10
  public        = true
}
```

**Pros:**

* **Explicit**: you `cd envs/prod` — it's obvious which environment you're in.
* **Strong isolation**: each environment can have its own backend bucket,
  project, and credentials.
* **Independent differences**: prod may add resources dev doesn't need
  (e.g. monitoring alerts) without conditionals.
* **Gradual promotion** is possible (18.5).
* Works naturally with CI/CD: one pipeline job per directory.

**Cons:** a little repetition (each environment has its own small
`main.tf`). Keep root modules thin — mostly module calls — so the
repetition stays small.

Tools such as **Terragrunt** reduce the remaining repetition further, and
**HCP Terraform** gives each environment its own workspace (Chapter 16).
Both follow the same idea: separate state and settings per environment, shared
modules.

### Comparison

| | CLI workspaces | tfvars per env | Directory per env |
|---|---|---|---|
| State isolation | Same backend | Separate possible | Separate |
| Credential isolation | Weak | Possible | Strong |
| Visible in code which env | No | Partly | Yes |
| Env-specific resources | Conditionals | Conditionals | Natural |
| Gradual promotion | No | No | Yes (with versioned modules) |
| Best for | Temporary copies | Small, simple setups | Most teams |

## 18.5 Promoting changes

With local module paths (`../../modules/web-app`), a module change affects
every environment the next time it's applied. The **pipeline** controls the
order: apply dev automatically, then staging, then prod after approval
(Chapters 21–22).

For stricter control, **version the module** (Git tags or a private
registry) and pin each environment to a version:

```hcl
# envs/dev/main.tf
module "web_app" {
  source = "git::https://github.com/acme/terraform-google-web-app.git?ref=v1.4.0"
  # ...
}

# envs/prod/main.tf — still on the previous release
module "web_app" {
  source = "git::https://github.com/acme/terraform-google-web-app.git?ref=v1.3.2"
  # ...
}
```

Promotion is then a small, reviewable pull request that bumps `v1.3.2` to
`v1.4.0` in `envs/prod`.

## 18.6 Keeping environments consistent

* **Same modules, different inputs.** Avoid copy-pasting resource blocks
  between environment directories.
* **Pin provider versions the same way** in every environment and upgrade them
  in order (dev first).
* **Detect drift** in every environment regularly (scheduled
  `terraform plan -detailed-exitcode` in CI, or HCP Terraform health
  assessments).
* **Name resources with the environment** (`dev-web`, `prod-web`) and **label
  them** (`environment = "prod"`) for cost reports.
* **Protect production**: `prevent_destroy` / `deletion_protection` on
  stateful resources, approvals, and least-privilege identities.

## Common mistakes and exam tips

* Applying to the wrong CLI workspace — check `terraform workspace show`.
* Sharing one state for all environments.
* Giving the dev pipeline permissions in prod.
* Letting environments diverge through manual changes.
* Thick root modules with lots of copy-pasted resources.

## Summary

* Separate dev, staging, and prod for safety; isolate them with separate
  projects, state, and identities.
* CLI workspaces give multiple states per configuration but weak isolation.
* A directory per environment calling shared modules is explicit, isolated,
  and pipeline-friendly.
* Promote changes in order, optionally with versioned modules.

## Quick check

1. Where does the `gcs` backend store the state of a CLI workspace called
   `prod` with `prefix = "app"`?
2. What does `terraform.workspace` return?
3. Give two disadvantages of CLI workspaces for environment separation.
4. Why are separate Google Cloud projects a good isolation boundary?
5. How can you roll out a module change to dev before prod in a
   directory-per-environment layout?

---

## Hands-on exercise: dev and prod from one module

**Goal:** Build a directory-per-environment layout that deploys a small web
app (Cloud Run + bucket) to `dev` and `prod`, with separate state, and try
CLI workspaces for comparison.

**Estimated time:** 30 minutes

**Files:** `code/ch18-environments/exercise/`

This layout is also used in Chapters 19 – 23.

### Steps

1. Look at `modules/web-app/`. It creates a service account, a bucket, and a
   Cloud Run service. Read its variables.
2. **dev.** In `envs/dev/`:
   * Copy `terraform.tfvars.example` to `terraform.tfvars` with your project
     ID.
   * Copy `backend.hcl.example` to `backend.hcl` with your state bucket from
     Chapter 10.
   * Complete the `module "web_app"` call (`min_instances = 0`,
     `max_instances = 2`; `environment = "dev"` is already set).
   * `terraform init -backend-config=backend.hcl` and `terraform apply`.
     Open the `url` output.
3. **prod.** Do the same in `envs/prod/` with `max_instances = 5` and
   `deletion_protection = true` (`environment = "prod"` is already set).
4. List the state objects: `gcloud storage ls -r gs://<state-bucket>/envs/`.
   Two separate states.
5. **Change the module**: add a label `team = "shop"` to the bucket in
   `modules/web-app/main.tf` (for example
   `labels = merge(local.labels, { team = "shop" })`). Plan in `envs/dev` (one change) and apply.
   Plan in `envs/prod` — the same change is pending there. In a real team,
   the pipeline would apply it to prod after approval. Apply it.
6. **Compare with CLI workspaces.** In `workspaces-demo/`, run:

   ```console
   $ terraform init
   $ terraform workspace new dev && terraform apply -auto-approve
   $ terraform workspace new prod && terraform apply -auto-approve
   $ terraform workspace list
   $ ls terraform.tfstate.d/
   ```

   Look at how the bucket names use `terraform.workspace`. Then destroy both:
   `terraform destroy -auto-approve`, `terraform workspace select dev`,
   `terraform destroy -auto-approve`.

### Expected result

Two independent environments (`dev-web-shop`, `prod-web-shop` services) with
state stored under `envs/dev/` and `envs/prod/` in your state bucket.

### Stretch goal

Add `envs/staging/` in under five minutes. What did you have to change?

### Cleanup

Keep `envs/dev` and `envs/prod` if you plan to continue with Chapters 19 –
21 (they're cheap: Cloud Run scales to zero). Otherwise:

```console
$ (cd envs/dev && terraform destroy)
$ (cd envs/prod && terraform destroy)   # set deletion_protection = false and apply first
```

If you run `destroy` in `envs/prod` while `deletion_protection` is still
`true`, it doesn't stop at the start: Terraform destroys the other resources
and then fails on the Cloud Run service with `cannot destroy service without
setting deletion_protection=false and running terraform apply`.

---

## Quick check answers

1. `app/prod.tfstate` in the bucket.
2. The name of the currently selected workspace (`default` if none was
   selected).
3. Any two: shared backend and credentials (weak isolation), the current
   environment isn't visible in code, easy to apply to the wrong one,
   differences hidden in conditionals, no gradual promotion.
4. Each project has its own IAM, quotas, APIs, and billing — a mistake or
   compromised identity in dev can't affect prod.
5. Apply dev first in the pipeline and prod after approval; or version the
   module and bump the version in `envs/dev` before `envs/prod`.
