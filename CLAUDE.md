# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A beginner book, *Introduction to Terraform on Google Cloud*: 23 one-hour
lessons plus appendices in `book/` (Markdown), and runnable Terraform for every
chapter in `code/`. It must cover the full Terraform Associate (004) exam, plus
multiple environments, testing, policy as code (`gcloud beta terraform vet`),
and CI/CD (GitHub Actions and Cloud Build). `SUMMARY.md` is the table of
contents (mdBook/MkDocs style).

## Versions are a hard constraint

`VERSIONS.md` is the single source of truth for every pinned version (Terraform
1.17.0, `hashicorp/google` 8.9.0, gcloud 591.0.0, actions, images, modules).

* Root modules use `required_version = "~> 1.17.0"` and **exact** provider pins
  (`version = "8.9.0"`). Reusable child modules (e.g. `modules/secure-bucket`,
  `modules/iap-ssh`) use ranges such as `">= 7.0, < 9.0"` and have no lock file.
* Root modules commit `.terraform.lock.hcl`; exercise directories carry a copy
  of the matching solution's lock file.
* If a version changes, update `VERSIONS.md`, every `versions.tf`, workflows,
  `cloudbuild/*.yaml`, `.tflint.hcl`, `.pre-commit-config.yaml`, and the
  chapter text, then regenerate lock files.
* The exam targets Terraform 1.12; features newer than that are marked
  **"Newer than the exam"** in the text.

## Book conventions

Every chapter follows the same template: Learning objectives (tagged with exam
IDs like `[4c]`) → concepts with code and CLI output → common mistakes / exam
tips → summary → 5 quick-check questions → hands-on exercise (goal, estimated
time, files, steps, expected result, stretch goal, cleanup) → quick-check
answers. Section numbers (`10.6`) are referenced from
`book/appendix-a-exam-objective-map.md`; keep that map in sync when sections
move or are renumbered.

Code snippets in chapters must match the files in `code/chNN-*/solution/`.
Exercise steps reference `TODO (step N)` markers in `exercise/` files, so
renumbering steps means updating those comments too.

## Code layout

`code/chNN-<slug>/{exercise,solution}/`. `exercise/` is the solution with parts
replaced by `TODO`s; it should still pass `validate` where possible (put TODOs in
comments rather than invalid values). Placeholders: project
`tf-book-fatih-12345`, HCP Terraform org `tf-book-yourname`. Real values go in
`terraform.tfvars` (git-ignored); `terraform.tfvars.example` is committed.

Default region throughout is `europe-west1` / bucket location `EU`.

Code that is shared across chapters is **copied**, not referenced, so a change
must be applied to every copy:

* `web-app` module: identical in `ch18-environments/solution/modules/web-app`,
  `ch19-testing/solution/web-app`, `ch21-github-actions/solution/repo/infra/modules/web-app`,
  and `ch22-cloud-build/solution/repo/infra/modules/web-app`. The ch23 capstone
  version is an extended variant (VPC egress, `secret_env`).
* `infra/` is identical between ch21 and ch22 `repo/`.
* The ch20 `policy-library/` is copied into the ch21/ch22/ch23 repos.

Multi-root chapters have an apply order: ch10 `bootstrap` → `network` → `app`
(app reads network outputs via `terraform_remote_state`); ch16/21/22 run a
`bootstrap/` (WIF pool, service accounts, triggers) before the pipeline repo;
ch18 `envs/dev|prod` use gcs prefix `envs/<env>`.

Expected failures, not bugs:

* `ch03-core-workflow/exercise` is intentionally unformatted (`fmt` exercise).
* `ch15-troubleshooting/exercise` contains six deliberate bugs, listed in
  `solution/BUGS.md` (note `terraform init` already catches the syntax ones).
* `ch17-hcp-governance/solution/consumer` fails `init` without
  `terraform login` (private registry module).

## Validating changes

Nothing here needs GCP credentials except real plans/applies and the vet CAI
path. Use the pinned Terraform 1.17.0 binary. For a changed root module:

```bash
cd code/chNN-*/solution/<root>
terraform fmt -check -recursive
terraform init -backend=false -input=false
terraform validate
```

Mocked unit tests (offline, `mock_provider`):

```bash
cd code/ch19-testing/solution/web-app            # or ch23-capstone/solution/infra/modules/web-app
terraform init -backend=false
terraform test -filter=tests/unit.tftest.hcl     # single file; integration.tftest.hcl needs a real project
```

Lint (TFLint 0.65.0 with the google ruleset from the directory's `.tflint.hcl`):

```bash
tflint --init && tflint --recursive
actionlint code/ch21-github-actions/solution/repo/.github/workflows/*.yml
```

Policy as code (ch20): `./vet.sh [CONFIG_DIR] [POLICY_LIBRARY]` plans, converts
to JSON and runs `gcloud beta terraform vet` (needs the `terraform-tools`
component and real credentials). Exit codes: 0 = no violations, 2 =
violations, other = error. Policy-library rules learned the hard way: a `lib/`
directory must exist, constraint names are lowercase-with-hyphens, templates
need an `openAPIV3Schema` (at least `properties: {}`), and the Rego rule must be
named `violation` and read `input.review` / `input.parameters`.

## Building and releasing the book

`epub/build.sh [OUTPUT] [VERSION]` builds the EPUB with pandoc 3.13 from
`epub/metadata.yaml` plus `book/[0-9]*.md book/appendix-*.md` (file names
define the order). `epub/links.lua` rewrites relative links to GitHub URLs
(base from `REPO_URL`), because files outside `book/` aren't in the EPUB.
Validate with `epubcheck <file>.epub`.

`.github/workflows/release-book.yml` builds and runs EPUBCheck on PRs touching
`book/` or `epub/`; pushing a `v*` tag also creates a GitHub release with the
EPUB attached. Pandoc and EPUBCheck are pinned by version **and** SHA-256 in
the workflow's `env`; update both when bumping.

## Status

All solution roots pass fmt/init/validate (except the ch17 consumer); unit
tests pass offline. Nothing has been applied against a real GCP project yet,
and the pipelines, HCP Terraform flows, integration tests, and vet's CAI path
are untested live.
