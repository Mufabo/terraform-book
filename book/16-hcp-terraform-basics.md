# Chapter 16 — HCP Terraform Basics

## Learning objectives

By the end of this lesson you will be able to:

* Explain what **HCP Terraform** is and what it adds to the Terraform CLI. `[8a]`
* Describe how HCP Terraform is organised: **organizations, projects, and
  workspaces**. `[8c]`
* Compare **CLI-driven, VCS-driven, and API-driven** workflows. `[8a]`
* Connect a configuration to HCP Terraform with the `cloud` block and
  `terraform login`. `[8d]`
* Configure workspace **variables** and **variable sets**. `[8c]`
* Authenticate HCP Terraform to Google Cloud with **dynamic provider
  credentials** (no keys). `[8d]`
* Create infrastructure with HCP Terraform. `[8a]`

---

## 16.1 What is HCP Terraform? `[8a]`

**HCP Terraform** (formerly *Terraform Cloud*) is HashiCorp's managed
service for running Terraform as a team. It's part of the HashiCorp Cloud
Platform (HCP) at <https://app.terraform.io>. **Terraform Enterprise** is the
self-hosted version of the same product, for organisations that need to run
it in their own data centre or cloud.

So far, Terraform ran on your laptop with state in a GCS bucket you
managed. HCP Terraform provides, out of the box:

| Feature | What it gives you |
|---|---|
| **Remote state storage** | Encrypted, versioned state with locking and history — no bucket to manage. |
| **Remote execution** | Plans and applies run on HashiCorp-managed workers, not laptops. Consistent environment, logs kept. |
| **VCS integration** | Automatic plans on pull requests, applies on merge. |
| **Variables and secrets** | Store variables (including sensitive ones) per workspace or shared in variable sets. |
| **Access control** | Teams and permissions per project and workspace (Chapter 17). |
| **Private registry** | Share modules and providers within the organisation (Chapter 17). |
| **Policy as code** | Sentinel and OPA policies checked on every run (Chapter 17). |
| **Run history and audit** | Who ran what, when, with which plan. |
| **Drift detection & health checks** | Scheduled checks for drift and `check` blocks (Chapter 17). |
| **Cost estimation** | Estimated monthly cost changes in the plan (for supported resources). |

HCP Terraform has a **free tier** suitable for this chapter, plus paid tiers
that unlock team management, policies, and more at scale. Pricing and
limits change; check <https://www.hashicorp.com/products/terraform/pricing>.

## 16.2 Organisation structure `[8c]`

```
Organization (e.g. "acme")              ← billing, settings, teams, registry
├── Project "networking"                ← group of workspaces + permissions
│   ├── Workspace "network-dev"
│   └── Workspace "network-prod"
└── Project "web-shop"
    ├── Workspace "web-shop-dev"
    ├── Workspace "web-shop-staging"
    └── Workspace "web-shop-prod"
```

* **Organization** — the top level, shared by your company. Holds teams,
  the private registry, policies, VCS connections, and billing.
* **Project** — a folder that groups related workspaces. Permissions and
  variable sets can be assigned to a project, so every workspace inside
  inherits them. Every organisation has a `Default Project`.
* **Workspace** — the unit of work. A workspace has:
  * its own **state**,
  * its own **variables**,
  * a **configuration** source (a VCS repository + directory, or uploads from
    the CLI),
  * settings (Terraform version, execution mode, auto-apply),
  * a run history and permissions.

A common pattern is **one workspace per configuration per environment**:
`network-dev`, `network-prod`, `app-dev`, `app-prod`.

### HCP Terraform workspaces vs. CLI workspaces

Confusingly, the Terraform CLI also has a feature called "workspaces"
(Chapter 18) — multiple state files for one configuration in one backend.
**HCP Terraform workspaces are much more**: each is a separate entity with
its own variables, permissions, settings, and history.

> **Exam tip:** HCP Terraform workspaces ≈ separate working directories with
> their own state, variables, and permissions. CLI workspaces = alternate
> state files in the same backend and directory.

Workspaces can be organised with **tags** (key/value), which the `cloud`
block can use to select a set of workspaces.

## 16.3 Workflows `[8a]`

| Workflow | How runs start | Typical use |
|---|---|---|
| **CLI-driven** | You run `terraform plan`/`apply` locally; the CLI uploads the configuration and the run executes remotely, streaming output to your terminal. | Getting started, migrating from local workflows. |
| **VCS-driven** | HCP Terraform watches a Git repository. Pull requests trigger *speculative plans* (plan-only, shown on the PR); merges to the main branch trigger a plan and apply. | The standard team GitOps workflow. |
| **API-driven** | An external tool (e.g. a CI pipeline) uploads configuration and creates runs through the API. | Custom pipelines, platform tooling. |

### Execution modes

Each workspace has an execution mode:

* **Remote** (default) — plans and applies run on HCP Terraform's workers.
* **Local** — runs happen on your machine; HCP Terraform only stores state.
* **Agent** — runs happen on **HCP Terraform agents** you host in your own
  network (paid tiers). Useful to reach private resources.

### Runs

A **run** goes through stages: *Pending → Plan → Cost estimation → Policy
check → Apply*. With **auto-apply** off (the default), someone must click
**Confirm & Apply** in the UI (or `terraform apply` in the CLI-driven
workflow asks for `yes`). Speculative plans (from PRs or
`terraform plan` in the CLI-driven workflow) can never be applied.

## 16.4 Connecting a configuration: `terraform login` and the `cloud` block `[8d]`

### 1. Authenticate the CLI

```console
$ terraform login
Terraform will request an API token for app.terraform.io using your browser.
...
Token for app.terraform.io:
  Enter a value: ******
Retrieved token for user fatih
```

The token is saved in `~/.terraform.d/credentials.tfrc.json`. In CI, use the
environment variable `TF_TOKEN_app_terraform_io` instead.

### 2. Add a `cloud` block

```hcl
terraform {
  required_version = "~> 1.17.0"

  cloud {
    organization = "acme"

    workspaces {
      project = "web-shop"
      name    = "web-shop-dev"
    }
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }
}
```

* `organization` — your HCP Terraform organisation.
* `workspaces.name` — use exactly one workspace; it's created on `init` if it
  doesn't exist.
* `workspaces.tags` — instead of `name`, select all workspaces with these
  tags; switch between them with `terraform workspace select`.
* `workspaces.project` — the project for new workspaces.
* `hostname` — defaults to `app.terraform.io`; set it for Terraform
  Enterprise.

These settings can also come from environment variables:
`TF_CLOUD_ORGANIZATION`, `TF_WORKSPACE`, `TF_CLOUD_PROJECT`, `TF_CLOUD_HOSTNAME`.

The `cloud` block replaces a `backend` block — you can't have both.

### 3. Initialise

```console
$ terraform init
Initializing HCP Terraform...
Do you wish to proceed?
  As part of migrating to HCP Terraform, Terraform can optionally copy your
  current workspace state to the configured HCP Terraform workspace.
  Enter a value: yes
HCP Terraform has been successfully initialized!
```

Existing local or GCS state is migrated to the workspace, just like in
Chapter 10.

### 4. Plan and apply

```console
$ terraform plan
Running plan in HCP Terraform. Output will stream here. Pressing Ctrl-C
will stop streaming the logs, but will not stop the plan running remotely.

Preparing the remote plan...

To view this run in a browser, visit:
https://app.terraform.io/app/acme/web-shop-dev/runs/run-AbC123...
```

The configuration is uploaded and executed remotely. Local `.tfvars` files
are **not** automatically sent (other than `*.auto.tfvars`); variables
belong in the workspace.

> **Exam tip:** The `cloud` block is the modern way to connect to HCP
> Terraform. You may still see the older `backend "remote"` in questions; it
> does the same job with less functionality.

## 16.5 Variables and variable sets `[8c]`

Each workspace has two kinds of variables:

| Kind | Used as | Example |
|---|---|---|
| **Terraform variable** | Value for `variable "..."` in the configuration (like a tfvars entry). Can be HCL. | `project_id = "acme-dev"` |
| **Environment variable** | Set in the run's shell environment. | `TFC_GCP_PROVIDER_AUTH=true`, `TF_LOG=DEBUG` |

Any variable can be marked **sensitive**: it becomes write-only — nobody can
read it back in the UI or API, and it's redacted in logs.

**Variable sets** are reusable groups of variables applied to many
workspaces, a whole project, or globally — for example, the Google Cloud
authentication settings shared by every workspace in a project.

Precedence (highest first): run-specific variables (e.g. `-var` in a CLI run)
→ workspace variables → variable sets (priority sets first) → `*.auto.tfvars`
in the configuration → defaults.

## 16.6 Dynamic provider credentials for Google Cloud `[8d]`

Remote runs need Google credentials. Storing a service account key as a
sensitive variable works but is a long-lived secret. **Dynamic provider
credentials** are better: for each run, HCP Terraform issues a signed
**OIDC token** describing the run (organisation, project, workspace, phase).
Google's **Workload Identity Federation** trusts tokens from HCP Terraform,
exchanges the token for short-lived Google credentials, and lets the run
impersonate a service account. No keys exist anywhere.

```
 HCP Terraform run ──(OIDC token: org=acme, workspace=web-shop-dev)──▶ Google STS
                                                                         │ checks pool/provider
                                                                         ▼
                   ◀──────── short-lived token for terraform-dev@... ────┘
```

### Google side (created once, with Terraform or gcloud)

```hcl
resource "google_iam_workload_identity_pool" "hcp" {
  workload_identity_pool_id = "hcp-terraform"
  display_name              = "HCP Terraform"
}

resource "google_iam_workload_identity_pool_provider" "hcp" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.hcp.workload_identity_pool_id
  workload_identity_pool_provider_id = "hcp-terraform-oidc"
  display_name                       = "HCP Terraform OIDC"

  attribute_mapping = {
    "google.subject"                        = "assertion.sub"
    "attribute.terraform_organization_name" = "assertion.terraform_organization_name"
    "attribute.terraform_workspace_name"    = "assertion.terraform_workspace_name"
  }

  # Only accept tokens from our organisation.
  attribute_condition = "assertion.terraform_organization_name == \"${var.hcp_organization}\""

  oidc {
    issuer_uri = "https://app.terraform.io"
  }
}

resource "google_service_account" "terraform" {
  account_id   = "hcp-terraform-dev"
  display_name = "Runs Terraform from HCP Terraform (dev)"
}

# Allow runs of one specific workspace to impersonate the service account.
resource "google_service_account_iam_member" "hcp_workload_identity" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.hcp.name}/attribute.terraform_workspace_name/${var.hcp_workspace}"
}

# What the service account may do in the project.
resource "google_project_iam_member" "terraform_editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.terraform.email}"
}
```

> **Security tip:** Always restrict the provider with an `attribute_condition`
> on your organisation name. Without it, *any* HCP Terraform organisation
> could present tokens to your pool. Restrict the service account binding to
> specific workspaces, and grant the narrowest roles possible (`roles/editor`
> keeps the exercise simple).

> [!NOTE]
> **Google Cloud: Workload Identity Federation.** WIF lets identities from
> outside Google, such as HCP Terraform runs or GitHub Actions jobs, use
> Google Cloud without keys. Its parts:
>
> * A **workload identity pool** is a container for external identities.
>   Deleted pool IDs stay reserved for 30 days, so you can't recreate a
>   pool with the same ID straight away.
> * A **provider** in the pool trusts one issuer of OIDC tokens
>   (`issuer_uri`). Its **attribute mapping** copies claims from the token
>   into Google attributes, and its **attribute condition** rejects tokens
>   that don't match.
> * Google's **Security Token Service** (STS) exchanges a valid external token
>   for a short-lived Google token.
> * The external identity is then named `principal://...` (one subject) or
>   `principalSet://.../attribute.NAME/VALUE` (everyone with that attribute
>   value). Granting it `roles/iam.workloadIdentityUser` on a service account
>   lets it impersonate that service account.

### HCP Terraform side (workspace or variable set environment variables)

| Environment variable | Value |
|---|---|
| `TFC_GCP_PROVIDER_AUTH` | `true` |
| `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL` | `hcp-terraform-dev@PROJECT_ID.iam.gserviceaccount.com` |
| `TFC_GCP_WORKLOAD_PROVIDER_NAME` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/hcp-terraform/providers/hcp-terraform-oidc` |

With these set, the Google provider in the run is authenticated automatically.
The provider block stays exactly as before — no credentials in code. You can
use different service accounts for plan and apply
(`TFC_GCP_PLAN_SERVICE_ACCOUNT_EMAIL`, `TFC_GCP_APPLY_SERVICE_ACCOUNT_EMAIL`),
for example a read-only account for speculative plans.

## 16.7 Managing HCP Terraform with Terraform

Workspaces, variables, teams, and projects can themselves be managed as code
with the **`hashicorp/tfe`** provider (version 0.82.0 at the time of
writing):

```hcl
resource "tfe_project" "web_shop" {
  organization = "acme"
  name         = "web-shop"
}

resource "tfe_workspace" "dev" {
  organization = "acme"
  project_id   = tfe_project.web_shop.id
  name         = "web-shop-dev"
}

resource "tfe_variable" "gcp_auth" {
  workspace_id = tfe_workspace.dev.id
  category     = "env"
  key          = "TFC_GCP_PROVIDER_AUTH"
  value        = "true"
}
```

This is how platform teams provision dozens of consistent workspaces.

## Common mistakes and exam tips

* Expecting `terraform.tfvars` to be used in remote runs — set workspace
  variables instead (or use `*.auto.tfvars`).
* Having both `cloud` and `backend` blocks.
* Forgetting `terraform login` (or `TF_TOKEN_app_terraform_io` in CI).
* Using a service account key instead of dynamic credentials.
* Confusing HCP Terraform workspaces with CLI workspaces.
* Speculative plans can't be applied.

## Summary

* HCP Terraform provides remote state, remote runs, VCS integration,
  variables, access control, registry, policies, and more. Terraform
  Enterprise is the self-hosted edition.
* Organization → projects → workspaces; each workspace has its own state,
  variables, settings, and permissions.
* CLI-driven, VCS-driven, and API-driven workflows; remote, local, or agent
  execution.
* Connect with `terraform login` and the `cloud` block.
* Dynamic provider credentials use OIDC and Workload Identity Federation —
  no long-lived Google keys.

## Quick check

1. What's the difference between an HCP Terraform workspace and a CLI
   workspace?
2. Which block connects a configuration to HCP Terraform?
3. What happens when a pull request is opened against a repository connected
   to a VCS-driven workspace?
4. Name the three environment variables needed for Google dynamic provider
   credentials.
5. What is a variable set?

---

## Hands-on exercise: Run Terraform in HCP Terraform with keyless auth

**Goal:** Create an HCP Terraform organisation and workspace, configure
dynamic credentials to Google Cloud, and create a bucket from a remote run.

**Estimated time:** 35 minutes

**Files:** `code/ch16-hcp-terraform/exercise/` with `wif/` (Google side,
run locally) and `app/` (runs in HCP Terraform).

### Steps

1. **Sign up** at <https://app.terraform.io> and create an organisation (the
   name must be globally unique, e.g. `tf-book-<yourname>`).
2. **Authenticate the CLI:** `terraform login`.
3. **Google side.** In `wif/`, create `terraform.tfvars` with your project ID,
   organisation name, and workspace name `ch16-app`. Complete the `TODO`s
   (pool, provider with attribute condition, service account, bindings),
   uncomment the outputs in `outputs.tf`, and apply locally. Note the outputs `workload_provider_name` and
   `service_account_email`.
4. **App configuration.** In `app/versions.tf`, complete the `cloud` block
   with your organisation, project `terraform-book`, and workspace `ch16-app`.
   Run `terraform init`. HCP Terraform creates the project and workspace
   if they don't exist.
5. **Workspace variables.** In the HCP Terraform UI, open the `ch16-app`
   workspace → *Variables* and add:
   * Terraform variable `project_id` = your project ID.
   * Environment variables `TFC_GCP_PROVIDER_AUTH` = `true`,
     `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL`, and
     `TFC_GCP_WORKLOAD_PROVIDER_NAME` from step 3's outputs.

   (Stretch: put the three environment variables into a **variable set**
   applied to the `terraform-book` project instead.)
6. Run `terraform plan`. Watch the output stream from the remote run, and open
   the run URL in your browser.
7. Run `terraform apply`, type `yes`. Look at the run in the UI: plan, apply,
   state version.
8. In the UI, open *States* and look at the state history. Click a state
   version to see its contents.
9. Try `terraform state list` locally — it reads from HCP Terraform.

### Expected result

A bucket created by a run in HCP Terraform, authenticated without any keys,
with state stored in the workspace.

### Stretch goal

Use the `tfe` provider (in `wif/` or a new folder) to create the workspace
and its environment variables as code instead of clicking.

### Cleanup

```console
$ (cd app && terraform destroy)      # runs remotely
$ (cd wif && terraform destroy)
```

Then delete the `ch16-app` workspace in the HCP Terraform UI
(*Settings → Destruction and Deletion*). Keep the organisation for Chapter 17.

---

## Quick check answers

1. An HCP Terraform workspace is a full entity with its own state,
   variables, settings, permissions, and run history; a CLI workspace is just
   an alternate state file for the same configuration and backend.
2. The `cloud` block inside the `terraform` block.
3. HCP Terraform runs a speculative (plan-only) run and reports the result on
   the pull request.
4. `TFC_GCP_PROVIDER_AUTH`, `TFC_GCP_RUN_SERVICE_ACCOUNT_EMAIL`,
   `TFC_GCP_WORKLOAD_PROVIDER_NAME`.
5. A reusable group of variables that can be applied to multiple workspaces,
   projects, or the whole organisation.
