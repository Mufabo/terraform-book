# Chapter 17 — Collaboration and Governance in HCP Terraform

## Learning objectives

By the end of this lesson you will be able to:

* Describe HCP Terraform's **collaboration** features: teams, permissions,
  VCS workflows, run triggers, notifications. `[8b]`
* Publish and consume modules from the **private registry**. `[8b]`
* Explain **policy as code** in HCP Terraform with **Sentinel** and **OPA**,
  including enforcement levels. `[8b]`
* Describe **run tasks**, **cost estimation**, **drift detection**, and
  **health assessments**. `[8b]`
* Organise workspaces and projects for many teams. `[8c]`

> Some features in this chapter require paid HCP Terraform tiers. The exam
> tests your *understanding* of them, not your billing plan. The exercise uses
> features available on the free tier where possible.

**Time:** about 1 hour — 20 reading, 5 quick check, 35 exercise.

---

## 17.1 Teams and permissions `[8b]`

In an organisation, users belong to **teams**. Permissions are granted to
teams — never to individual users — at three levels:

| Level | Examples of permissions |
|---|---|
| **Organization** | Manage policies, manage VCS settings, manage the private registry, manage all projects/workspaces, manage membership. |
| **Project** | Fixed roles: *Read*, *Write*, *Maintain*, *Admin* — or custom. Applies to all workspaces in the project. |
| **Workspace** | Fixed roles: *Read*, *Plan*, *Write*, *Admin* — or custom (e.g. can queue plans but not apply, can read state outputs only). |

Workspace roles in more detail:

| Role | Can |
|---|---|
| **Read** | See runs, state versions, variables (not sensitive values). |
| **Plan** | Read + queue speculative plans. |
| **Write** | Plan + apply runs, lock workspaces, edit variables. |
| **Admin** | Write + change settings, manage team access, delete the workspace. |

The special **owners** team has full control of the organisation. Use it
sparingly.

Typical setup:

* *platform* team: Admin on `networking` project.
* *web-shop developers*: Write on `web-shop` dev/staging workspaces, Plan on
  prod.
* *web-shop leads*: Write on prod.
* *auditors*: Read on everything.

Additional collaboration and security features:

* **Single sign-on (SSO)** with your identity provider (Okta, Entra ID,
  Google Workspace via SAML) and **two-factor authentication** enforcement.
* **Audit trails**: an API that records every action in the organisation.
* **Team and organisation API tokens** for automation (prefer short-lived
  tokens and least privilege).

## 17.2 Collaboration workflows `[8b]`

* **VCS-driven runs** (Chapter 16): pull requests get speculative plans whose
  results appear as a status check on the PR; merges trigger runs. Code review
  and infrastructure review happen in one place.
* **Run approvals**: with auto-apply off, someone with *Write* access must
  confirm each apply. Comments can be added to runs.
* **Workspace locking**: lock a workspace to prevent runs during maintenance.
* **Run triggers**: automatically queue a run in workspace B when workspace A
  applies successfully (e.g. `app-prod` re-plans after `network-prod`
  changes).
* **Sharing outputs**: workspaces can be allowed to read each other's outputs
  (`tfe_outputs` data source or `terraform_remote_state` with the `remote`
  backend), with explicit, scoped permission.
* **Notifications**: send run events to Slack, Microsoft Teams, email, or a
  webhook.
* **Projects** keep related workspaces, their permissions, and variable sets
  together. Use naming conventions such as `<app>-<component>-<env>` and
  tags (`env:prod`, `team:web`) to find and select workspaces.

### Reading another workspace's outputs with `tfe_outputs`

To let `app-prod` read `network-prod`'s outputs, first allow it in
`network-prod` under *Settings → General → Remote state sharing* (share with
specific workspaces rather than the whole organisation). Then use the
`tfe_outputs` data source from the `hashicorp/tfe` provider (Chapter 16):

```hcl
terraform {
  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "0.82.0"
    }
  }
}

data "tfe_outputs" "network" {
  organization = "tf-book-yourname"
  workspace    = "network-prod"
}

resource "google_cloud_run_v2_service" "app" {
  # ...
  template {
    vpc_access {
      network_interfaces {
        subnetwork = data.tfe_outputs.network.nonsensitive_values.subnet_id
      }
    }
  }
}
```

* `values` contains every output and is marked **sensitive** as a whole.
  `nonsensitive_values` contains only the outputs that weren't declared
  `sensitive = true`, so you can use them without the plan hiding them.
* Unlike `terraform_remote_state`, `tfe_outputs` reads only the outputs, not
  the full state, so the consumer never sees the producer's resource
  attributes. It still sees only **root** outputs (see section 10.6).
* Inside HCP Terraform runs, the provider authenticates automatically. Locally
  it uses your `terraform login` token.
* Combine it with a **run trigger** so `app-prod` re-plans whenever
  `network-prod` applies.

## 17.3 The private registry `[8b]`

The **private registry** is like the public Terraform Registry, but visible
only to your organisation. Teams publish approved modules (and even private
providers), and everyone consumes them with versioned addresses:

```hcl
module "logs_bucket" {
  source  = "app.terraform.io/acme/secure-bucket/google"
  version = "~> 1.0"

  project_id = var.project_id
  name       = "acme-logs"
}
```

The source format is `<HOSTNAME>/<ORGANIZATION>/<NAME>/<PROVIDER>`.

### Publishing a module

* **Branch-based or tag-based publishing from VCS**: connect a repository
  named `terraform-<PROVIDER>-<NAME>` (e.g. `terraform-google-secure-bucket`).
  With tag-based publishing, every semantic-version Git tag (`v1.0.0`) becomes
  a module version.
* **API publishing**: upload versions from a pipeline.

The registry shows the README, inputs, outputs, resources, and examples,
generated from the code — the same as the public registry.

### No-code modules

Modules can be marked **no-code ready**. Users without Terraform knowledge can
then create a workspace from the module by filling in a form in the UI —
self-service infrastructure with guardrails built in.

> **Exam tip:** Private registry module sources include the hostname
> (`app.terraform.io/...`). Authentication to the private registry uses the
> same token as `terraform login`.

## 17.4 Policy as code: Sentinel and OPA `[8b]`

**Policy as code** means writing company rules — "buckets must be in the EU",
"all resources need a `cost_center` label", "no VMs larger than 8 vCPUs" — as
code that's automatically checked on every run, between plan and apply.

HCP Terraform supports two policy languages:

| | **Sentinel** | **Open Policy Agent (OPA)** |
|---|---|---|
| Origin | HashiCorp's own policy language | Open-source CNCF project; language **Rego** |
| Data available | Plan (`tfplan/v2`), configuration (`tfconfig/v2`), state (`tfstate/v2`), run info (`tfrun`) | Plan JSON as `input` |
| Enforcement levels | **advisory**, **soft-mandatory**, **hard-mandatory** | **advisory**, **mandatory** |

### Enforcement levels

| Level | On failure |
|---|---|
| **Advisory** | Warning shown; the run continues. |
| **Soft-mandatory** (Sentinel) | Run stops, but a user with permission can **override** and continue. |
| **Hard-mandatory** (Sentinel) / **Mandatory** (OPA) | Run stops; no override possible. Fix the code or the policy. |

> **Exam tip:** Know the three Sentinel enforcement levels and that only
> soft-mandatory failures can be overridden. Policy checks run **after the
> plan and before the apply**.

### A Sentinel policy

`restrict-bucket-location.sentinel`:

```sentinel
import "tfplan/v2" as tfplan
import "strings"

allowed_locations = ["EU", "EUROPE-WEST1", "EUROPE-WEST3", "EUROPE-WEST4"]

buckets = filter tfplan.resource_changes as _, rc {
  rc.type is "google_storage_bucket" and
  (rc.change.actions contains "create" or rc.change.actions contains "update")
}

violations = filter buckets as address, rc {
  strings.to_upper(rc.change.after.location) not in allowed_locations
}

for violations as address, _ {
  print(address, "is not in an allowed location", allowed_locations)
}

main = rule {
  length(violations) is 0
}
```

Policies are grouped in **policy sets**, defined by a `sentinel.hcl` file:

```hcl
policy "restrict-bucket-location" {
  source            = "./restrict-bucket-location.sentinel"
  enforcement_level = "hard-mandatory"
}

policy "require-labels" {
  source            = "./require-labels.sentinel"
  enforcement_level = "soft-mandatory"
}
```

A policy set is connected to a VCS repository (or uploaded via the API) and
applied to the whole organisation, specific projects, or specific workspaces.

### The same rule in OPA (Rego)

`bucket_location.rego`:

```rego
package terraform.policies.bucket_location

import rego.v1

allowed := {"EU", "EUROPE-WEST1", "EUROPE-WEST3", "EUROPE-WEST4"}

deny contains msg if {
  some rc in input.plan.resource_changes
  rc.type == "google_storage_bucket"
  some action in rc.change.actions
  action in {"create", "update"}
  not upper(rc.change.after.location) in allowed
  msg := sprintf("%s is in %s, which is not allowed", [rc.address, rc.change.after.location])
}
```

`policies.hcl`:

```hcl
policy "bucket-location" {
  query             = "data.terraform.policies.bucket_location.deny"
  enforcement_level = "mandatory"
}
```

A policy passes when the query returns an empty set.

> **Newer than the exam:** Terraform 1.17 made **Terraform Policy** generally
> available in the CLI (`terraform plan -policies=DIR`), so policies can also
> be evaluated locally. Chapter 20 shows a Google-native alternative,
> `gcloud terraform vet`, which works without HCP Terraform.

## 17.5 Run tasks `[8b]`

**Run tasks** call external services at defined stages of a run and can block
it based on the response:

| Stage | Example integrations |
|---|---|
| **Pre-plan** | Check the configuration (e.g. static analysis). |
| **Post-plan** | Security scanning of the plan (e.g. Snyk, Palo Alto Prisma, Wiz), cost tools (Infracost). |
| **Pre-apply** | Final approval from a change-management system (e.g. ServiceNow). |
| **Post-apply** | Notify or verify after changes. |

Each run task has an enforcement level of **advisory** or **mandatory**.

## 17.6 Cost estimation `[8b]`

With cost estimation enabled, HCP Terraform estimates the **monthly cost
change** of a plan for supported Google Cloud, AWS, and Azure resources and
shows it in the run. Sentinel policies can use the estimate
(`tfrun.cost_estimate`) — for example, to require approval when a change adds
more than $100/month.

## 17.7 Drift detection and health assessments `[8b]`

**Health assessments** run on a schedule in the background:

* **Drift detection** — a refresh-only plan that alerts you when real
  infrastructure no longer matches state (Chapter 11).
* **Continuous validation** — re-evaluates `check` blocks and
  pre/postconditions (Chapter 8), e.g. "certificate expires in more than 30
  days", "website returns 200".

Results appear in the workspace's *Health* tab and can trigger notifications.

## 17.8 Organising at scale `[8c]`

* **Projects per application or team**; workspaces per component and
  environment inside.
* **Variable sets per project** for shared settings (e.g. cloud credentials
  for that project's Google Cloud projects).
* **Policy sets** global for company-wide rules, project-scoped for team
  rules.
* **Private registry** for approved modules; no-code modules for
  self-service.
* **Explorer** (in the UI) to query all workspaces: versions in use, modules,
  providers, drift status.
* Manage all of this as code with the `tfe` provider.

## Common mistakes and exam tips

* Granting permissions to users directly instead of teams.
* Confusing workspace roles: *Plan* can't apply; *Write* can.
* Expecting to override a hard-mandatory policy.
* Forgetting that policy checks happen between plan and apply.
* Private registry sources need the hostname prefix.

## Summary

* Teams get permissions at organisation, project, and workspace level.
* VCS workflows, run triggers, approvals, and notifications support
  collaboration.
* The private registry shares approved, versioned modules.
* Sentinel and OPA enforce policies with advisory, soft-mandatory, or
  hard-mandatory (OPA: mandatory) levels.
* Run tasks integrate external tools; cost estimation, drift detection, and
  continuous validation keep infrastructure healthy.

## Quick check

1. Which Sentinel enforcement level allows an authorised user to override a
   failure?
2. At which point in a run are policies evaluated?
3. What is the module source format for the private registry?
4. Name two things a health assessment can detect.
5. What is a run trigger?

---

## Hands-on exercise: Private registry and policy enforcement

**Goal:** Publish your module from Chapter 13 in the private registry, consume
it from a workspace, and block non-compliant changes with a policy.

**Estimated time:** 35 minutes

**Files:** `code/ch17-hcp-governance/exercise/`

> You need a GitHub account and the HCP Terraform organisation from Chapter
> 16. If your tier doesn't include policies, read through part B and run the
> policy locally in Chapter 20 instead.

### Part A — Private registry

1. Create a public or private GitHub repository named
   `terraform-google-secure-bucket` and push the contents of
   `code/ch17-hcp-governance/exercise/terraform-google-secure-bucket/`
   (the module from Chapter 13) to it.
2. Tag a release: `git tag v1.0.0 && git push --tags`.
3. In HCP Terraform: *Registry → Publish → Module*, connect GitHub (create a
   VCS connection when asked), choose the repository, and select
   **tag-based** publishing. Version `1.0.0` appears.
4. In `consumer/versions.tf`, set your organisation in the `cloud` block. In
   `consumer/main.tf`, uncomment and complete the `module` block (and the
   output below it), using the private registry source
   `app.terraform.io/<org>/secure-bucket/google` and `version = "~> 1.0"`.
5. Reuse the Chapter 16 setup: run `wif/` from Chapter 16 again with
   `hcp_workspace = "ch17-consumer"` (or add a second binding), and set the
   same variables on the new `ch17-consumer` workspace (a variable set on the
   project makes this easy).
6. `terraform init` and `terraform apply` in `consumer/`.

### Part B — Policy

7. Create a second GitHub repository (e.g. `tf-policies`) with the contents of
   `policies/` (Sentinel policy + `sentinel.hcl`).
8. In HCP Terraform: *Settings → Policy sets → Connect a new policy set*,
   choose the repository, scope it to the `ch17-consumer` workspace.
   Start with `enforcement_level = "advisory"`.
9. In `consumer/main.tf`, change the bucket location to `US`. Run
   `terraform plan`. The policy check fails with a **warning**; the run could
   continue.
10. Change the level to `hard-mandatory` in `sentinel.hcl`, push, and plan
    again: the run is **blocked**.
11. Revert the location to `EU` and plan: the policy passes.

### Expected result

A module consumed from your private registry, and a policy that warns and
then blocks buckets outside Europe.

### Stretch goal

Write the second policy `require-labels.sentinel` that requires every bucket
to have an `owner` label, set it to `soft-mandatory`, and practise overriding
it in the UI.

### Cleanup

```console
$ (cd consumer && terraform destroy)
$ (cd ../../ch16-hcp-terraform/exercise/wif && terraform destroy)   # re-applied in step 5
```

Delete the workspace, the policy set, and (optionally) the registry module in
the UI. Archive or delete the two GitHub repositories
(`terraform-google-secure-bucket` and `tf-policies`).

---

## Quick check answers

1. Soft-mandatory.
2. After the plan (and cost estimation) and before the apply.
3. `<HOSTNAME>/<ORGANIZATION>/<NAME>/<PROVIDER>`, e.g.
   `app.terraform.io/acme/secure-bucket/google`.
4. Drift (infrastructure changed outside Terraform) and failing `check`
   blocks or pre/postconditions (continuous validation).
5. A setting that automatically queues a run in one workspace after a
   successful apply in another workspace.
