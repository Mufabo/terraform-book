# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A beginner book, *Introduction to Terraform on Google Cloud*: 22 lessons
of about an hour each plus appendices in `book/` (Markdown), and runnable
Terraform for every chapter in `code/`. It must cover the full Terraform Associate (004) exam, plus
multiple environments, testing, policy as code (`gcloud beta terraform vet`),
and CI/CD (GitHub Actions). `SUMMARY.md` is the table of
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
  `.tflint.hcl`, `.pre-commit-config.yaml`, and the chapter text, then
  regenerate lock files.
* The exam targets Terraform 1.12; features newer than that are marked
  **"Newer than the exam"** in the text.

## Book conventions

Every chapter follows the same template: Learning objectives (tagged with exam
IDs like `[4c]`, followed by a `**Time:**` line) → concepts with code and CLI
output → common mistakes / exam tips → summary → quick check (5 recall
questions, then 2 multiple-choice "Scenario questions" numbered 6 and 7) →
hands-on exercise (goal, estimated time, files, steps, expected result,
stretch goal, challenge, cleanup) → quick-check answers. Google Cloud concepts are explained in GitHub-style alert boxes
(`> [!NOTE]` followed by `> **Google Cloud: <topic>.**`) where the concept
first appears; the EPUB build renders them via pandoc's `alerts` extension
and `epub/style.css`. Section numbers (`10.6`) are referenced from
`book/appendix-a-exam-objective-map.md`; keep that map in sync when sections
move or are renumbered.

Vary the position of the correct option in multiple-choice questions.
Chapter 22 has two practice tests: Part C (recall, answers in Part D) and
Part E (scenarios, answers in Part F).

The `**Time:**` line is reading (words before the hands-on exercise at 100
words a minute, rounded to 5 minutes) + 5 minutes quick check + the
exercise's estimated time. The preface repeats every chapter's time in a
table, so update both when a chapter grows or an exercise estimate changes.

Code snippets in chapters must match the files in `code/chNN-*/solution/`.
Exercise steps reference `TODO (step N)` markers in `exercise/` files, so
renumbering steps means updating those comments too.

## Code layout

`code/chNN-<slug>/{exercise,solution}/`. `exercise/` is the solution with parts
replaced by `TODO`s; it should still pass `validate` where possible (put TODOs in
comments rather than invalid values). Placeholders: project
`tf-book-fatih-12345`, HCP Terraform org `tf-book-yourname`. Real values go in
`terraform.tfvars` (git-ignored); `terraform.tfvars.example` is committed.

Chapters 1–21 also have a `challenge/` folder: the reference solution of the
chapter's unscaffolded "Challenge" task (requirements only, no `TODO`s; the
task text is in the chapter, after the stretch goal). Challenge roots follow
the same version and lock-file rules as solutions. Explanations live in an
`answers.md`, `SOLUTION.md`, `NOTES.md`, or `BUGS.md` next to the code. Not
every challenge is a single root: ch09 has `platform/` and `teams/`, ch10
`storage/`, ch15 `broken/` and `fixed/`, ch19 `secure-bucket/` (a module with
tests), ch20 only policy YAML, ch21 only a workflow. Resource names in
challenges carry a `chNNc-` prefix so they never clash with the exercise.

Default region throughout is `europe-west1` / bucket location `EU`.

`ch02-setup/solution/project-bootstrap` (project, billing link, budget and
APIs as Terraform) is described in `book/appendix-e-project-with-terraform.md`,
not in Chapter 2.

Code that is shared across chapters is **copied**, not referenced, so a change
must be applied to every copy:

* `web-app` module: identical in `ch18-environments/solution/modules/web-app`,
  `ch19-testing/solution/web-app`, and
  `ch21-github-actions/solution/repo/infra/modules/web-app`. The ch22 capstone
  version is an extended variant (VPC egress, `secret_env`).
* `ch22-capstone/solution/bootstrap-github` is the ch21 `bootstrap/` except
  for the pool ID (`web-shop-github`; deleted pool IDs stay reserved for 30
  days). Apply identities bind to `attribute.environment`, because new GitHub
  repos get immutable OIDC subjects with numeric IDs.
* The ch20 `policy-library/` is copied into the ch21 repo and the ch22
  capstone. It bans `allUsers` on Cloud Run, so the ch21/ch22 envs set
  `public = false`.

* The `secure-bucket` module from
  `ch13-writing-modules/solution/modules/secure-bucket` is copied to
  `ch17-hcp-governance` (as `terraform-google-secure-bucket`) and to
  `ch19-testing/challenge/secure-bucket` (with unit tests).
* `ch18-environments/challenge` calls `../solution/modules/web-app` directly.

Multi-root chapters have an apply order: ch10 `bootstrap` → `network` → `app`
(app reads network outputs via `terraform_remote_state`); ch16/21 run a
`bootstrap/` (WIF pool, service accounts) and the ch22 capstone a
`bootstrap-github/` before the pipeline repo; ch18 `envs/dev|prod` use gcs
prefix `envs/<env>`.

Expected failures, not bugs:

* `ch03-core-workflow/exercise` is intentionally unformatted (`fmt` exercise).
* `ch15-troubleshooting/exercise` contains six deliberate bugs, listed in
  `solution/BUGS.md` (note `terraform init` already catches the syntax ones).
* `ch15-troubleshooting/challenge/broken` contains four deliberate bugs,
  listed in `challenge/BUGS.md` (`validate` fails with a cycle).
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
cd code/ch19-testing/solution/web-app            # or ch22-capstone/solution/infra/modules/web-app
terraform init -backend=false
terraform test -filter=tests/unit.tftest.hcl     # single file; integration.tftest.hcl needs a real project
```

Lint (TFLint 0.65.0 with the google ruleset from the directory's `.tflint.hcl`):

```bash
tflint --init && tflint --recursive
```

actionlint (1.7.12) resolves `uses: ./.github/workflows/...` relative to the
Git root, so run it in a copy of `repo/` that is its own repository:
`cp -r code/ch21-github-actions/solution/repo/.github /tmp/x/ && cd /tmp/x && git init -q && actionlint`.

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
tests pass offline. Chapters 2–15 and 18–22 were run live against a real
project in November 2026, including the integration tests, vet's CAI path,
and the ch21 GitHub Actions pipeline end to end (with a private repo, so the
prod approval and branch ruleset were not exercised: GitHub Free only offers
them for public repos). Untested live: HCP Terraform (ch16/17, only validated
and the ch16 `wif/` planned) and the Sentinel policies.

The challenge solutions (added later) pass fmt/init/validate, and the ch19
challenge's unit tests pass offline, but **none was applied**. Chapters 6–8
and 12–14 were additionally checked with read-only plans. Not run at all:
the ch20 challenge template (never passed through `vet`), the ch21 destroy
workflow (actionlint only), and the ch16/17 `tfe` configurations.
