# Chapter 21 — CI/CD with GitHub Actions

## Learning objectives

By the end of this lesson you will be able to:

* Explain why Terraform should run in a **CI/CD pipeline** instead of on
  laptops.
* Design a pipeline: **checks and plan on pull requests, apply on merge**.
* Authenticate GitHub Actions to Google Cloud with **Workload Identity
  Federation** — no service account keys.
* Separate **plan** and **apply** identities and protect production with
  **GitHub environments** and required reviewers.
* Build workflows that run `fmt`, TFLint, `terraform test`, `plan`,
  `gcloud terraform vet`, and `apply`, and post the plan to the pull request.

---

## 21.1 Why CI/CD for Terraform?

Running `terraform apply` from laptops works for one person. In a team it
causes problems:

* Different Terraform and provider versions, different local changes.
* Powerful credentials on every engineer's machine.
* No guarantee that what was reviewed is what was applied.
* No record of who applied what, and when.

A pipeline fixes this:

* **One consistent environment** with pinned versions.
* **Credentials only in the pipeline**, short-lived and scoped.
* **Every change goes through a pull request** with the plan visible to
  reviewers.
* **Automated checks** (format, lint, tests, policies) on every change.
* **History**: every run is logged.

This is often called **GitOps** for infrastructure: Git is the source of
truth, and merging is the way to change production.

## 21.2 The pipeline design

```
 feature branch ──▶ pull request ──────────────────────────────▶ merge to main
                    │                                              │
                    ▼ terraform-pr.yml                              ▼ terraform-apply.yml
     ┌───────────────────────────────┐            ┌──────────────────────────────┐
     │ static: fmt, tflint,          │            │ dev:  plan → vet → apply      │
     │         terraform test (mock) │            │          (automatic)          │
     │ plan (dev, prod) with the     │            │              │                │
     │   read-only plan identity     │            │              ▼                │
     │ gcloud terraform vet          │            │ prod: ⏸ approval required     │
     │ comment plan on the PR        │            │       plan → vet → apply      │
     └───────────────────────────────┘            └──────────────────────────────┘
```

Repository layout (from Chapters 18–20):

```
web-shop-infra/
├── .github/workflows/
│   ├── terraform-pr.yml          # pull requests
│   ├── terraform-apply.yml       # pushes to main: dev, then prod
│   └── terraform-apply-env.yml   # reusable: apply one environment
├── .tflint.hcl
├── policy-library/               # Chapter 20
└── infra/
    ├── modules/web-app/          # Chapter 18, with tests/ from Chapter 19
    └── envs/
        ├── dev/
        └── prod/
```

## 21.3 Keyless authentication: Workload Identity Federation

GitHub Actions can issue an **OIDC token** for each job: a signed statement
such as "this job runs in repository `acme/web-shop-infra`, on ref
`refs/heads/main`, in environment `prod`". Google's **Workload Identity
Federation** (WIF) can be configured to trust these tokens and exchange them
for short-lived Google credentials that impersonate a service account.

```
GitHub job ──OIDC token (repo, ref, environment)──▶ Google STS + WIF provider
                                                      │ attribute_condition ok?
                                                      ▼
           ◀──── 1-hour access token for tf-apply-prod@... ──── IAM: workloadIdentityUser
```

No keys are created, stored, or rotated. Tokens expire within an hour.

### The identities

We use the **principle of least privilege** with three service accounts:

| Service account | Used by | Permissions | Who may impersonate it |
|---|---|---|---|
| `tf-plan` | PR plans | Viewer + Security Reviewer (read only), state bucket access | Any workflow in the repository |
| `tf-apply-dev` | dev apply job | Editor (+ IAM admin) in dev | Only jobs in GitHub environment `dev` |
| `tf-apply-prod` | prod apply job | Editor (+ IAM admin) in prod | Only jobs in GitHub environment `prod` |

Binding the apply identities to a **GitHub environment** is the key security
property: a malicious pull request can't modify the workflow to apply to
production, because only jobs running in the `prod` environment — which
requires a reviewer's approval — receive the `environment:prod` claim that
Google checks.

> In real setups, dev and prod live in **different Google Cloud projects**
> (Chapter 18) and each apply identity only has roles in its own project.
> Here everything is in your single learning project.

### Bootstrap with Terraform

The `bootstrap/` configuration (run once, locally, by an administrator)
creates the pool, the provider, and the service accounts:

```hcl
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"        = "assertion.sub"
    "attribute.repository"  = "assertion.repository"
    "attribute.ref"         = "assertion.ref"
    "attribute.environment" = "assertion.environment"
  }

  # Only tokens issued for our repository are accepted.
  attribute_condition = "assertion.repository == \"${var.github_repository}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}
```

The plan identity can be used by any job in the repository:

```hcl
resource "google_service_account_iam_member" "plan_wif" {
  service_account_id = google_service_account.plan.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}
```

The apply identities only by jobs in the matching environment. A job that
runs in a GitHub environment gets an `environment` claim in its token, which
the provider maps to `attribute.environment`:

```hcl
resource "google_service_account_iam_member" "apply_wif" {
  for_each = var.environments

  service_account_id = google_service_account.apply[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.environment/${each.key}"
}
```

This principal set alone would match an environment of that name in *any*
repository; the provider's `attribute_condition` is what limits it to yours.
Why not bind to the token's subject, `repo:OWNER/NAME:environment:ENV`, as
older guides do? GitHub now issues **immutable subjects** for new
repositories, with numeric owner and repository IDs
(`repo:OWNER@123/NAME@456:environment:prod`), so a subject written with names
no longer matches. The `repository` and `environment` claims keep their plain
values.

> **Security tip:** Always set an `attribute_condition`. Without it, tokens
> from *any* GitHub repository could be presented to your pool.

The bootstrap outputs the values the workflows need. Store them as
**repository variables** (not secrets — none of them is secret):

| Variable | Example |
|---|---|
| `GCP_PROJECT_ID` | `tf-book-fatih-12345` |
| `GCP_WIF_PROVIDER` | `projects/123456789/locations/global/workloadIdentityPools/github/providers/github-oidc` |
| `GCP_PLAN_SA` | `tf-plan@tf-book-fatih-12345.iam.gserviceaccount.com` |
| `GCP_APPLY_SA_DEV` | `tf-apply-dev@tf-book-fatih-12345.iam.gserviceaccount.com` |
| `GCP_APPLY_SA_PROD` | `tf-apply-prod@tf-book-fatih-12345.iam.gserviceaccount.com` |
| `TF_STATE_BUCKET` | `tf-book-fatih-12345-tfstate` |

## 21.4 The pull request workflow

`terraform-pr.yml` has two jobs.

### Job 1: static checks and unit tests (no credentials)

```yaml
  static:
    name: Static checks and unit tests
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@v7.0.1

      - uses: hashicorp/setup-terraform@v4.0.1
        with:
          terraform_version: ${{ env.TF_VERSION }}   # "1.17.0"
          terraform_wrapper: false

      - name: terraform fmt
        run: terraform fmt -check -recursive infra

      - name: Install TFLint
        run: |
          curl -sSLo tflint.zip "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip"
          mkdir -p "$HOME/.local/bin"
          unzip -q tflint.zip -d "$HOME/.local/bin"
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"

      - name: tflint
        env:
          GITHUB_TOKEN: ${{ github.token }}
        run: |
          tflint --init --config "$GITHUB_WORKSPACE/.tflint.hcl"
          tflint --recursive --config "$GITHUB_WORKSPACE/.tflint.hcl" --chdir infra

      - name: Module unit tests (mocked, no credentials)
        working-directory: infra/modules/web-app
        run: |
          terraform init -backend=false
          terraform test -filter=tests/unit.tftest.hcl
```

Notes:

* Every action is pinned to an exact version tag (see VERSIONS.md). For even
  stronger supply-chain security, pin to the commit SHA instead
  (`uses: actions/checkout@<40-character-sha> # v7.0.1`).
* `terraform_wrapper: false` disables setup-terraform's wrapper script so
  exit codes and output behave exactly like the plain CLI.

### Job 2: plan and vet, per environment

```yaml
  plan:
    name: Plan and vet (${{ matrix.environment }})
    needs: static
    runs-on: ubuntu-24.04
    strategy:
      fail-fast: false
      matrix:
        environment: [dev, prod]
    permissions:
      contents: read
      id-token: write       # request the GitHub OIDC token
      pull-requests: write  # comment the plan on the pull request
    defaults:
      run:
        working-directory: infra/envs/${{ matrix.environment }}
    env:
      TF_VAR_project_id: ${{ vars.GCP_PROJECT_ID }}
    steps:
      - uses: actions/checkout@v7.0.1

      - id: auth
        uses: google-github-actions/auth@v3.0.0
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ vars.GCP_PLAN_SA }}

      - uses: google-github-actions/setup-gcloud@v3.0.1
        with:
          version: ${{ env.GCLOUD_VERSION }}          # "591.0.0"
          install_components: beta,terraform-tools

      - uses: hashicorp/setup-terraform@v4.0.1
        with:
          terraform_version: ${{ env.TF_VERSION }}
          terraform_wrapper: false

      - name: terraform init
        run: terraform init -backend-config="bucket=${{ vars.TF_STATE_BUCKET }}"

      - name: terraform validate
        run: terraform validate

      - name: terraform plan
        id: plan
        run: |
          set +e
          terraform plan -lock-timeout=120s -detailed-exitcode -out=tfplan -no-color > plan.txt
          code=$?
          cat plan.txt
          echo "exitcode=$code" >> "$GITHUB_OUTPUT"
          [ "$code" -ne 1 ]

      - name: Policy check (gcloud terraform vet)
        id: vet
        run: |
          terraform show -json tfplan > tfplan.json
          set +e
          gcloud beta terraform vet tfplan.json \
            --policy-library="$GITHUB_WORKSPACE/policy-library" \
            --format=json > violations.json
          code=$?
          cat violations.json
          echo "exitcode=$code" >> "$GITHUB_OUTPUT"
          exit $code
```

What happens here:

* **`id-token: write`** allows the job to request an OIDC token. Without it,
  the auth step fails.
* `google-github-actions/auth` exchanges the token for credentials and exports
  them (as a credentials file and environment variables) for Terraform and
  `gcloud`.
* The backend bucket comes from **partial configuration** (Chapter 10); the
  project ID from `TF_VAR_project_id` (Chapter 6).
* `-detailed-exitcode` returns `2` when there are changes; the script treats
  only `1` as failure.
* `gcloud beta terraform vet` fails the job on policy violations (exit code 2),
  which blocks the merge if the check is required.

A final step posts a summary and the plan as a pull request comment using
the `gh` CLI, which is pre-installed on GitHub runners:

```yaml
      - name: Comment plan on the pull request
        if: always() && steps.plan.outcome != 'skipped'
        env:
          GH_TOKEN: ${{ github.token }}
          ...
        run: |
          ...
          gh pr comment "$PR_NUMBER" --repo "$GITHUB_REPOSITORY" --body-file comment.md
```

### Make the checks required

In GitHub: *Settings → Branches → Add branch ruleset* for `main`: require a
pull request with at least one approval and require the status checks
*Static checks and unit tests*, *Plan and vet (dev)*, and *Plan and vet
(prod)*. Now nobody can merge code that's unformatted, fails tests, or
violates policies. (Rulesets on private repositories also need a paid plan,
and GitHub doesn't let you approve your own pull request, so on a
one-person repository leave out the approval requirement.)

> **Security tip:** Pull requests from **forks** don't get OIDC tokens or
> repository variables by default, so they can't plan. That's intentional:
> never run Terraform with cloud credentials on untrusted code. Avoid
> `pull_request_target` for Terraform workflows.

## 21.5 The apply workflow

`terraform-apply.yml` runs on every push to `main` (i.e. after a merge). It
calls a **reusable workflow** once per environment, dev first:

```yaml
concurrency:
  group: terraform-apply-${{ github.ref }}
  cancel-in-progress: false

jobs:
  dev:
    uses: ./.github/workflows/terraform-apply-env.yml
    permissions:
      contents: read
      id-token: write
    with:
      environment: dev

  prod:
    needs: dev
    uses: ./.github/workflows/terraform-apply-env.yml
    permissions:
      contents: read
      id-token: write
    with:
      environment: prod
```

* `concurrency` makes sure two applies never run at the same time (state
  locking would catch it too, but this avoids failed runs).
* `needs: dev` — prod only starts after dev applied successfully.
* A called workflow can't have more permissions than its caller, so the
  caller grants `id-token: write`.

`terraform-apply-env.yml`:

```yaml
jobs:
  apply:
    name: Apply (${{ inputs.environment }})
    runs-on: ubuntu-24.04
    environment: ${{ inputs.environment }}
    permissions:
      contents: read
      id-token: write
    ...
    steps:
      - uses: actions/checkout@v7.0.1

      - uses: google-github-actions/auth@v3.0.0
        with:
          workload_identity_provider: ${{ vars.GCP_WIF_PROVIDER }}
          service_account: ${{ inputs.environment == 'prod' && vars.GCP_APPLY_SA_PROD || vars.GCP_APPLY_SA_DEV }}

      # setup-gcloud and setup-terraform as before ...

      - name: terraform init
        run: terraform init -backend-config="bucket=${{ vars.TF_STATE_BUCKET }}"

      - name: terraform plan
        run: terraform plan -lock-timeout=300s -out=tfplan

      - name: Policy check (gcloud terraform vet)
        run: |
          terraform show -json tfplan > tfplan.json
          gcloud beta terraform vet tfplan.json --policy-library="$GITHUB_WORKSPACE/policy-library"

      - name: terraform apply
        run: terraform apply -lock-timeout=300s tfplan
```

* **`environment:`** puts the job into a GitHub environment. The environment's
  **protection rules** apply before the job starts, and the OIDC token
  contains `environment:<name>`, which the Google side requires for the apply
  identity.
* The job creates a **fresh plan**, re-checks policies, and applies exactly
  that saved plan (`terraform apply tfplan` never asks for confirmation and
  refuses stale plans).

### Protecting production with environments

In GitHub: *Settings → Environments*:

* **dev** — no protection rules: deploys automatically after merge.
* **prod** — **required reviewers** (one or more people or teams), optionally
  a wait timer and "prevent self-review", and restrict deployment branches to
  `main`.

On GitHub Free, required reviewers work only in **public** repositories;
private repositories need a paid plan. Without them, prod deploys right after
dev.

When the apply workflow reaches the prod job, it pauses with *Waiting for
review*. A reviewer opens the run, reads the dev result (and ideally the PR's
prod plan), and clicks **Approve and deploy**.

> **Why re-plan instead of applying the PR's plan?** Between the PR plan and
> the merge, other changes may have been merged or infrastructure may have
> drifted. Re-planning on `main` gives an up-to-date plan. Teams that want
> "apply exactly what was reviewed" can store the PR's plan file as an
> artifact and apply it — Terraform refuses if it has become stale.

## 21.6 Drift detection on a schedule (optional)

Add a scheduled workflow that runs
`terraform plan -detailed-exitcode -refresh-only` every night with the plan
identity and fails (or opens an issue) when the exit code is `2`. This catches
changes made outside the pipeline (Chapter 11).

```yaml
on:
  schedule:
    - cron: "0 5 * * 1-5"   # 05:00 UTC, Monday–Friday
```

## Common mistakes and tips

* Missing `permissions: id-token: write` → `Unable to get ACTIONS_ID_TOKEN_REQUEST_URL`.
* Missing or wrong `attribute_condition` → either everyone can authenticate
  (bad) or nobody can (`unauthorized_client`).
* Using one powerful identity for plan and apply.
* Using `-auto-approve` on a fresh plan instead of applying a saved plan.
* Unpinned actions (`@main`) or Terraform versions.
* Printing secrets: don't `cat` state or `terraform output -json` with
  sensitive values in logs.

## Summary

* CI/CD makes Terraform changes consistent, reviewed, and auditable.
* Pull requests run static checks, unit tests, plans, and policy checks; the
  plan is posted for reviewers.
* Merges trigger applies: dev automatically, prod after approval in a
  protected GitHub environment.
* Workload Identity Federation provides keyless, short-lived credentials;
  separate plan and apply identities and bind the apply identities to GitHub
  environments.

## Quick check

1. Which workflow permission is required for keyless authentication to
   Google Cloud?
2. Why is the prod apply service account bound to the token's
   `environment` claim (`prod`) instead of the whole repository?
3. Why do we use `terraform_wrapper: false`?
4. What does `concurrency` achieve in the apply workflow?
5. Why shouldn't pull requests from forks run Terraform plans with cloud
   credentials?

---

## Hands-on exercise: A keyless GitHub Actions pipeline

**Goal:** Push the web-shop infrastructure to GitHub, configure Workload
Identity Federation, and deploy dev and prod through pull requests with plan
comments, policy checks, and a production approval.

**Estimated time:** 45 minutes

**Files:** `code/ch21-github-actions/exercise/` with `bootstrap/` and
`repo/`.

### Steps

1. **Create a GitHub repository**, e.g. `web-shop-infra`. Make it public
   if you want to try the prod approval (step 3) and the branch ruleset
   (step 9): on GitHub Free, both are available only for public
   repositories. With a private repository, everything else works, and prod
   deploys without an approval.
2. **Bootstrap Google Cloud.** In `bootstrap/`, create `terraform.tfvars`
   (project, `OWNER/web-shop-infra`, state bucket from Chapter 10). Complete
   the two `TODO`s in `main.tf` (the attribute condition, and the
   `apply_wif` binding for `attribute.environment`, which you uncomment). `terraform init && terraform apply`. Keep the
   `github_variables` output open.
3. **Configure GitHub.**
   * *Settings → Secrets and variables → Actions → Variables*: create one
     repository variable for each entry of `github_variables`.
   * *Settings → Environments*: create `dev` (no rules) and `prod` with
     yourself as **required reviewer**.
4. **Complete the workflows** in `repo/.github/workflows/`: the auth step in
   `terraform-pr.yml`, the vet step, and the `environment:` line in
   `terraform-apply-env.yml`. Optionally lint them with
   [actionlint](https://github.com/rhysd/actionlint).
5. **Push.** Copy the contents of `repo/` into your repository clone, commit
   to `main`, and push. The apply workflow runs: dev deploys, prod waits for
   your approval. Approve it. The services are **private** (`public =
   false`), because the policy library bans `allUsers` on Cloud Run. Call
   one with an identity token:
   `curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" <url>`. (If you deployed `envs/dev`/`envs/prod` locally
   in Chapter 18 with the same state bucket, the pipeline simply takes over
   that state.)
6. **Make a change through a pull request.** Create a branch, change
   `max_instances` in `infra/envs/dev/main.tf` to `3`, push, and open a PR.
   Watch the checks and the plan comments for dev and prod.
7. **Break a policy.** On the same branch, remove the `managed_by` label from
   `local.labels` in the module. Push. The static checks pass (the unit tests
   only check the `environment` label), but the *Plan and vet* jobs fail with
   a policy violation. Restore the label and push again. (Setting
   `public_access_prevention = "inherited"` would be caught even earlier: a
   unit test fails, and *Plan and vet* doesn't run at all.)
8. **Merge** the PR. Dev applies automatically; approve prod.
9. **Require checks:** add a branch ruleset for `main` requiring the three
   checks (public repository, or a paid plan for a private one). Add the
   one-approval rule only if someone else can review your pull requests.

### Expected result

Merging a pull request deploys to dev automatically and to prod after your
approval — with no service account keys anywhere.

### Stretch goal

Add a nightly drift-detection workflow (section 21.6) that runs a
refresh-only plan for both environments with the plan identity.

### Cleanup

Destroy through the pipeline or locally:

```console
$ cd repo/infra/envs/prod && terraform init -backend-config="bucket=<state-bucket>" && terraform destroy
$ cd ../dev && terraform init -backend-config="bucket=<state-bucket>" && terraform destroy
$ cd ../../../../bootstrap && terraform destroy
```

(Set `deletion_protection = false` in prod and apply before destroying.)
Archive or delete the GitHub repository.

Google keeps a deleted workload identity pool for 30 days, and its ID can't
be reused in that time. To run the bootstrap again within 30 days, restore
the pool first (`gcloud iam workload-identity-pools undelete github
--location=global`) and import it, or choose a different pool ID.

---

## Quick check answers

1. `id-token: write`.
2. So that only jobs running in the protected `prod` GitHub environment
   (which require a reviewer's approval) can obtain production credentials.
   (The book binds to the token's `environment` claim rather than its
   subject, because new repositories get immutable subjects with numeric
   IDs.)
   Any other workflow in the repository, including a modified one in a pull
   request, can't.
3. The wrapper script changes how output and exit codes are handled; disabling
   it gives plain CLI behaviour (e.g. reliable `-detailed-exitcode`).
4. It prevents two apply runs for the same branch from running at the same
   time; the second waits.
5. Fork code is untrusted; running it with cloud credentials could leak or
   abuse them. GitHub therefore doesn't give fork PRs OIDC tokens or
   variables by default.
