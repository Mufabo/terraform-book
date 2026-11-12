# Chapter 21 challenge: a manual destroy workflow

Copy `.github/workflows/terraform-destroy.yml` into your repository.

> The workflow passes `actionlint`, but it has not been run on GitHub.

Design decisions:

* **`workflow_dispatch` only.** Destroying must never follow from a push or
  a pull request. The inputs are a `choice` (no typos, no surprise
  directory names) and a typed confirmation.
* **Inputs go through `env:`**, not straight into the script. Writing
  `${{ inputs.confirm }}` inside `run:` would paste whatever was typed into
  the shell script: a script injection.
* **`environment:`** gives the job the same protection as an apply: prod
  waits for the required reviewer, and only then does the job get the
  `environment` claim that lets it use `tf-apply-prod`. The plan identity
  couldn't destroy anything: it is read-only.
* **Same `concurrency` group as the apply workflow** (`terraform-apply-` plus
  the ref), so a destroy and an apply for `main` never overlap.
* **Saved plan.** `plan -destroy -out=tfplan`, then `apply tfplan`: what the
  log shows is exactly what is destroyed. No `-auto-approve`.
* **No `vet` step.** Policies check what is created or changed; a destroy
  plan has nothing for them to check, so the workflow doesn't install
  `gcloud` at all.
* **Only from `main`.** Otherwise someone could run the workflow from a
  branch whose code differs from what is deployed.

Things it does not do, on purpose:

* It doesn't switch off `deletion_protection`. Destroying prod therefore
  fails until a reviewed pull request sets `deletion_protection = false` and
  the normal pipeline applies it. Two deliberate steps for an irreversible
  action.
* It doesn't delete the state object or the bootstrap resources.
