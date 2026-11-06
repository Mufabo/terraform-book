# Chapter 22 — CI/CD with Google Cloud Build

## Learning objectives

By the end of this lesson you will be able to:

* Explain how **Cloud Build** runs pipelines as a sequence of container
  steps.
* Write `cloudbuild.yaml` files that run Terraform checks, plans, policy
  checks, and applies.
* Create Cloud Build **triggers** for pull requests and pushes with
  Terraform.
* Use dedicated, least-privilege **service accounts** per trigger instead of
  keys.
* Require **manual approval** before production builds run.
* Compare Cloud Build with GitHub Actions for Terraform pipelines.

---

## 22.1 Why Cloud Build?

**Cloud Build** is Google Cloud's serverless CI/CD service. For Terraform on
Google Cloud it has some attractive properties:

* **No external credentials at all.** Builds run *as* a Google service
  account. There's no OIDC federation to configure — the identity is native.
* **Runs inside your Google Cloud project**, with audit logs, VPC options
  (private pools), and organisation policies applying to it.
* **Built-in approvals** for triggers.
* Works with GitHub, GitLab, Bitbucket, and Cloud Source Repositories.

The pipeline design is the same as in Chapter 21: checks and plan on pull
requests, apply on merge, approval for production.

## 22.2 How Cloud Build works

A build is defined in a YAML file (here `cloudbuild/plan.yaml` and
`cloudbuild/apply.yaml`). Each **step** runs a **container image**:

```yaml
steps:
  - id: fmt
    name: hashicorp/terraform:1.17.0     # container image
    args: ["fmt", "-check", "-recursive", "infra"]
```

* `name` — the image. Its entrypoint receives `args`. Here the
  `hashicorp/terraform` image's entrypoint is `terraform`, so the step runs
  `terraform fmt -check -recursive infra`.
* `entrypoint` — override the entrypoint, e.g. `sh` to run a small script.
* `dir` — working directory, relative to `/workspace`.
* `id` — a name for the step, shown in logs.

All steps share the **`/workspace`** directory, which contains the checked-out
repository. Files created in one step (`.terraform/`, `tfplan`) are visible
to the next. Steps run **in order** by default; a failing step stops the
build.

### Substitutions

Values in `${...}` are **substitutions**:

* Built-in: `$PROJECT_ID`, `$BUILD_ID`, `$COMMIT_SHA`, `$BRANCH_NAME`, …
* User-defined (must start with `_`): `_ENV`, `_STATE_BUCKET`, set by the
  trigger or with defaults in the file:

```yaml
substitutions:
  _TF_IMAGE: hashicorp/terraform:1.17.0
  _TFLINT_IMAGE: ghcr.io/terraform-linters/tflint:v0.65.0
  _GCLOUD_IMAGE: gcr.io/google.com/cloudsdktool/google-cloud-cli:591.0.0-debian_component_based
```

Pinning images to exact tags gives the same reproducibility as pinning
versions in GitHub Actions.

### Options

```yaml
options:
  logging: CLOUD_LOGGING_ONLY      # required when a trigger uses its own service account
  env:
    - TF_IN_AUTOMATION=true
    - TF_INPUT=false
    - TF_VAR_project_id=$PROJECT_ID
```

`env` sets environment variables for every step — here Terraform's automation
settings and the `project_id` variable.

## 22.3 The pull request build: `cloudbuild/plan.yaml`

```yaml
steps:
  - id: fmt
    name: $_TF_IMAGE
    args: ["fmt", "-check", "-recursive", "infra"]

  - id: tflint
    name: $_TFLINT_IMAGE
    entrypoint: sh
    args:
      - -c
      - |
        tflint --init --config /workspace/.tflint.hcl
        tflint --recursive --config /workspace/.tflint.hcl --chdir infra

  - id: unit-tests
    name: $_TF_IMAGE
    dir: infra/modules/web-app
    entrypoint: sh
    args:
      - -c
      - |
        terraform init -backend=false
        terraform test -filter=tests/unit.tftest.hcl

  - id: init
    name: $_TF_IMAGE
    dir: infra/envs/${_ENV}
    args: ["init", "-backend-config=bucket=${_STATE_BUCKET}"]

  - id: validate
    name: $_TF_IMAGE
    dir: infra/envs/${_ENV}
    args: ["validate"]

  - id: plan
    name: $_TF_IMAGE
    dir: infra/envs/${_ENV}
    entrypoint: sh
    args:
      - -c
      - |
        terraform plan -lock-timeout=120s -out=tfplan
        terraform show -json tfplan > tfplan.json

  - id: vet
    name: $_GCLOUD_IMAGE
    dir: infra/envs/${_ENV}
    entrypoint: bash
    args:
      - -c
      - |
        gcloud components install terraform-tools --quiet
        gcloud beta terraform vet tfplan.json --policy-library=/workspace/policy-library
```

Different tools, different images: `terraform` for Terraform, `tflint` for
linting, the Google Cloud CLI for `terraform vet`. The standard Google Cloud
CLI images don't include the `terraform-tools` component, so the vet step
installs it first (the `debian_component_based` image variant allows
installing components).

Credentials: Terraform and `gcloud` in every step automatically use the
**trigger's service account** through the metadata server. Nothing to
configure.

If `vet` finds violations, it exits with code 2, the step fails, and the
build reports failure on the pull request.

## 22.4 The apply build: `cloudbuild/apply.yaml`

```yaml
steps:
  - id: init
    name: $_TF_IMAGE
    dir: infra/envs/${_ENV}
    args: ["init", "-backend-config=bucket=${_STATE_BUCKET}"]

  - id: plan
    name: $_TF_IMAGE
    dir: infra/envs/${_ENV}
    entrypoint: sh
    args:
      - -c
      - |
        terraform plan -lock-timeout=300s -out=tfplan
        terraform show -json tfplan > tfplan.json

  - id: vet
    name: $_GCLOUD_IMAGE
    dir: infra/envs/${_ENV}
    entrypoint: bash
    args:
      - -c
      - |
        gcloud components install terraform-tools --quiet
        gcloud beta terraform vet tfplan.json --policy-library=/workspace/policy-library

  - id: apply
    name: $_TF_IMAGE
    dir: infra/envs/${_ENV}
    args: ["apply", "-lock-timeout=300s", "tfplan"]
```

Same pattern as GitHub Actions: plan, check policies, apply the **saved** plan.

## 22.5 Service accounts and permissions

Each trigger runs as its own **user-specified service account**:

| Service account | Trigger(s) | Roles |
|---|---|---|
| `cb-tf-plan` | `tf-plan-dev`, `tf-plan-prod` | `roles/viewer`, `roles/iam.securityReviewer`, `roles/logging.logWriter`, state bucket `objectAdmin` |
| `cb-tf-apply-dev` | `tf-apply-dev` | `roles/editor`, `roles/resourcemanager.projectIamAdmin`, `roles/logging.logWriter`, state bucket `objectAdmin` |
| `cb-tf-apply-prod` | `tf-apply-prod` | same as dev, in the prod project |

* The plan identity can read but not change infrastructure — a malicious pull
  request can't use it to modify anything.
* `roles/logging.logWriter` lets builds write logs (needed with
  `CLOUD_LOGGING_ONLY`).
* Whoever creates or updates a trigger needs permission to *act as* the
  trigger's service account (`roles/iam.serviceAccountUser`).
* In real setups, each environment's apply account has roles only in its own
  project.

> Avoid the legacy **default Cloud Build service account**
> (`PROJECT_NUMBER@cloudbuild.gserviceaccount.com`). New projects don't grant
> it broad permissions anymore, and dedicated accounts per trigger are easier
> to audit and restrict.

## 22.6 Triggers as code

A **trigger** starts a build when something happens in a repository. Create
them with Terraform (`bootstrap/main.tf`):

```hcl
resource "google_cloudbuild_trigger" "plan" {
  for_each = var.environments

  name            = "tf-plan-${each.key}"
  location        = "global"
  filename        = "cloudbuild/plan.yaml"
  service_account = google_service_account.plan.id

  github {
    owner = var.github_owner
    name  = var.github_repository

    pull_request {
      branch          = "^main$"
      comment_control = "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"
    }
  }

  included_files = ["infra/**", "policy-library/**", "cloudbuild/**"]

  substitutions = {
    _ENV          = each.key
    _STATE_BUCKET = var.state_bucket
  }
}

resource "google_cloudbuild_trigger" "apply" {
  for_each = var.environments

  name            = "tf-apply-${each.key}"
  location        = "global"
  filename        = "cloudbuild/apply.yaml"
  service_account = google_service_account.apply[each.key].id

  github {
    owner = var.github_owner
    name  = var.github_repository

    push {
      branch = "^main$"
    }
  }

  included_files = ["infra/**", "policy-library/**", "cloudbuild/**"]

  approval_config {
    approval_required = contains(var.approval_environments, each.key)
  }

  substitutions = {
    _ENV          = each.key
    _STATE_BUCKET = var.state_bucket
  }
}
```

* `pull_request` triggers run for pull requests targeting `main`;
  `push` triggers run on commits to `main` (merges).
* `comment_control = "COMMENTS_ENABLED_FOR_EXTERNAL_CONTRIBUTORS_ONLY"` means
  pull requests from external contributors only build after a maintainer
  comments `/gcbrun` — protecting your credentials from untrusted code.
* `included_files` limits triggers to relevant changes.
* `substitutions` pass `_ENV` and `_STATE_BUCKET` into the build — one build
  file serves every environment.

### Connecting the repository

Before triggers can reference a GitHub repository, it must be **connected**
to Cloud Build once, in the console: *Cloud Build → Triggers → Connect
repository → GitHub (Cloud Build GitHub App)*, authorise, install the app on
your repository. This OAuth step can't be done by Terraform (Cloud Build's
"2nd gen" repository connections can be managed with
`google_cloudbuildv2_connection`, but still need a one-time authorisation).

## 22.7 Approvals for production

With `approval_config { approval_required = true }`, every build from the
`tf-apply-prod` trigger starts in the state **Awaiting approval**. Someone
with the **Cloud Build Approver** role (`roles/cloudbuild.builds.approver`)
reviews it and approves or rejects:

```console
$ gcloud builds list --filter='status="PENDING"' --format="table(id,substitutions._ENV,createTime)"
$ gcloud builds approve BUILD_ID --comment="dev looks good"
```

…or with the *Approve* button on the build in the console.

Note: Cloud Build triggers run independently, so `tf-apply-dev` and
`tf-apply-prod` both start on a merge. The approval gate is where a human
confirms that dev is healthy before prod proceeds. (For strict
dev-then-prod ordering, have the dev build trigger the prod build at its end
with `gcloud builds triggers run`, or use **Cloud Deploy** for full release
pipelines.)

## 22.8 Feedback on pull requests

With the Cloud Build GitHub App, each `tf-plan-*` build appears as a **check**
on the pull request, with a link to the logs that contain the plan and any
policy violations. Make these checks **required** in your branch ruleset,
just like in Chapter 21.

## 22.9 GitHub Actions or Cloud Build?

| | GitHub Actions | Cloud Build |
|---|---|---|
| Identity in Google Cloud | Workload Identity Federation (OIDC) | Native service account |
| Where runs execute | GitHub-hosted runners (or self-hosted) | Google Cloud (optionally private pools in your VPC) |
| Production gate | GitHub environments + required reviewers | Trigger approvals (`roles/cloudbuild.builds.approver`) |
| Pipeline definition | Workflows with jobs, matrix, reusable workflows, marketplace actions | Sequential container steps per build |
| Plan comment on PR | Easy (`gh pr comment`) | Check with log link (comment needs extra tooling) |
| Fits best | Teams living in GitHub, multi-cloud | Google Cloud–centric orgs, private networking, no external CI |

Both are excellent. The Terraform parts — pinned versions, partial backend
configuration, plan/vet/apply, separate identities, approval for prod — are
identical, which is the real lesson.

## Common mistakes and tips

* Forgetting `options.logging: CLOUD_LOGGING_ONLY` (or a logs bucket) with a
  user-specified service account → the build fails to start.
* Missing `roles/logging.logWriter` on the build service account → no logs.
* Using substitutions that aren't defined (Cloud Build rejects unknown
  user substitutions) or not prefixing user substitutions with `_`.
* Giving the plan trigger's account write permissions.
* Not pinning container image tags (`hashicorp/terraform:latest`).

## Summary

* Cloud Build runs pipelines as container steps sharing `/workspace`.
* `plan.yaml` runs checks, tests, plan, and `terraform vet` on pull requests;
  `apply.yaml` plans, vets, and applies on pushes to `main`.
* Triggers (created with Terraform) select the build file, the service
  account, substitutions, and events.
* Each trigger runs as a dedicated service account — no keys, no federation.
* Approval-required triggers protect production.

## Quick check

1. How do steps in a Cloud Build build share files?
2. What prefix must user-defined substitutions have?
3. Why does each trigger use a different service account?
4. How do you require a manual approval before prod applies?
5. What does `comment_control` protect against?

---

## Hands-on exercise: The same pipeline on Cloud Build

**Goal:** Run the web-shop pipeline from Chapter 21 on Cloud Build with
triggers, per-trigger service accounts, policy checks, and a production
approval.

**Estimated time:** 40 minutes

**Files:** `code/ch22-cloud-build/exercise/` with `bootstrap/` and `repo/`.

### Steps

1. **Repository.** Use the GitHub repository from Chapter 21 (or create a new
   one) and copy `repo/cloudbuild/` into it. If you use a new repository, copy
   all of `repo/`. (You can disable the GitHub Actions workflows in the
   repository settings to avoid running both pipelines.)
2. **Connect** the repository in the console: *Cloud Build → Triggers →
   Connect repository → GitHub (Cloud Build GitHub App)*. Choose region
   *global*. Don't create a trigger in the wizard.
3. **Complete the `TODO`s**: the `approval_config` in `bootstrap/main.tf`, the
   `vet` step in `repo/cloudbuild/plan.yaml`, and the `apply` step in
   `repo/cloudbuild/apply.yaml`. Commit and push the build files.
4. **Bootstrap.** In `bootstrap/`, create `terraform.tfvars` and run
   `terraform init && terraform apply`. Check the four triggers in the console.
5. **Grant yourself approval rights:**

   ```console
   $ gcloud projects add-iam-policy-binding $PROJECT_ID \
       --member="user:$(gcloud config get-value account)" \
       --role="roles/cloudbuild.builds.approver"
   ```

6. **Pull request.** Create a branch, change `max_instances` in
   `infra/envs/dev/main.tf`, push, and open a PR. Two checks appear
   (`tf-plan-dev`, `tf-plan-prod`). Open the build logs and find the plan
   output and the `vet` result.
7. **Policy failure.** Push a commit that sets the module bucket's
   `public_access_prevention` to `"inherited"`. The vet step fails. Revert.
8. **Merge.** `tf-apply-dev` runs immediately. `tf-apply-prod` waits for
   approval. Check the dev service URL, then approve the prod build in the
   console or with `gcloud builds approve`.

### Expected result

A merge deploys dev automatically and prod after your approval — entirely
within Google Cloud, with dedicated service accounts and no keys.

### Stretch goal

Add a fifth trigger `tf-drift-<env>` with a schedule (Cloud Scheduler +
`google_cloudbuild_trigger` with `source_to_build`) that runs
`terraform plan -refresh-only -detailed-exitcode` nightly.

### Cleanup

```console
$ cd bootstrap && terraform destroy
```

Destroy the environments as described in Chapter 21 if you no longer need
them, and disconnect the repository in the Cloud Build console.

---

## Quick check answers

1. Through the shared `/workspace` directory, which persists between steps.
2. An underscore, e.g. `_ENV`.
3. Least privilege: the plan trigger only reads, each apply trigger can only
   change its own environment, and access is easy to audit.
4. Set `approval_config { approval_required = true }` on the prod trigger and
   grant reviewers `roles/cloudbuild.builds.approver`.
5. Builds from untrusted external contributors running automatically with
   your service account; a maintainer must comment `/gcbrun` first.
