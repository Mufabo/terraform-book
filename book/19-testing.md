# Chapter 19 — Testing Terraform Code

## Learning objectives

By the end of this lesson you will be able to:

* Explain the **testing pyramid** for infrastructure code: static checks,
  unit tests, integration tests, and end-to-end tests.
* Run **static checks** with `terraform fmt`, `terraform validate`, and
  **TFLint** with the Google ruleset.
* Write tests with the native **`terraform test`** framework: `run` blocks,
  `assert`, `command = plan` vs `apply`, and `expect_failures`.
* Test modules **without credentials or cost** using `mock_provider` and
  overrides.
* Write an integration test that creates and destroys real resources.
* Automate checks before every commit with **pre-commit** hooks.

**Time:** about 55 minutes — 20 reading, 5 quick check, 30 exercise.

---

## 19.1 Why test infrastructure code?

Infrastructure code is code. A typo in a module used by fifty workspaces can
break fifty environments. Tests help you:

* catch mistakes **before** they reach a plan in production,
* change modules with confidence (refactoring, provider upgrades),
* document how a module is supposed to behave,
* review pull requests faster — the pipeline already checked the basics.

## 19.2 The testing pyramid

```
                 ▲   slow, expensive, realistic
                ╱ ╲
               ╱E2E╲        deploy the whole system, test it as a user
              ╱─────╲
             ╱ Integ-╲      create real resources with one module, verify, destroy
            ╱ ration  ╲
           ╱───────────╲
          ╱    Unit     ╲   plan (or mocked apply) and assert on values
         ╱───────────────╲
        ╱     Static      ╲  fmt, validate, tflint, policy checks (Chapter 20)
       ╱───────────────────╲
                             fast, free, run on every commit
```

| Level | Tools | Needs cloud? | Speed |
|---|---|---|---|
| Static | `fmt`, `validate`, TFLint, `gcloud terraform vet` | No (vet needs a plan) | Seconds |
| Unit | `terraform test` with `command = plan` or mock providers | No (with mocks) | Seconds |
| Integration | `terraform test` with `command = apply`, Terratest | Yes | Minutes |
| End-to-end | Deploy a full environment, run application tests | Yes | Minutes–hours |

Run the cheap levels on every commit; run integration tests on pull requests
for modules, or nightly.

## 19.3 Static checks

### `terraform fmt -check` and `terraform validate`

You know these (Chapter 3). In CI:

```console
$ terraform fmt -check -recursive
$ terraform init -backend=false
$ terraform validate
```

`-backend=false` lets you validate without access to the state bucket.

### TFLint

`validate` checks that your code is *valid Terraform*. **TFLint** (version
0.65.0) goes further: it finds likely mistakes and style issues, and with the
**Google ruleset** it knows Google-specific rules — for example invalid
machine types or regions that `validate` can't detect.

Install it from <https://github.com/terraform-linters/tflint/releases> and
create `.tflint.hcl`:

```hcl
config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "google" {
  enabled = true
  version = "0.41.0"
  source  = "github.com/terraform-linters/tflint-ruleset-google"
}
```

```console
$ tflint --init          # downloads the pinned plugins
$ tflint --recursive
```

Example findings:

```console
Error: "e2-mikro" is an invalid as machine type (google_compute_instance_invalid_machine_type)

  on main.tf line 3:
   3:   machine_type = "e2-mikro"

Warning: [Fixable] variable "unused" is declared but not used (terraform_unused_declarations)

  on variables.tf line 12:
```

The `recommended` preset of the Terraform plugin catches unused variables,
missing version constraints, deprecated syntax, and more.

## 19.4 The `terraform test` framework

Terraform has a built-in test framework. Tests are written in HCL, in files
ending in **`.tftest.hcl`**, usually in a `tests/` folder next to the module:

```
web-app/
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── tests/
    ├── unit.tftest.hcl
    └── integration.tftest.hcl
```

```console
$ terraform init
$ terraform test
tests/unit.tftest.hcl... in progress
  run "names_follow_convention"... pass
  run "bucket_is_private_and_labelled"... pass
...
Success! 7 passed, 0 failed.
```

### Anatomy of a test file

```hcl
variables {                         # defaults for all runs in this file
  project_id  = "test-project"
  region      = "europe-west1"
  environment = "dev"
}

run "names_follow_convention" {     # one test case
  command = plan                    # plan (fast, no resources) or apply

  assert {
    condition     = google_cloud_run_v2_service.app.name == "dev-web-shop"
    error_message = "Service name should be <environment>-<app_name>."
  }
}
```

* A **`run` block** executes `plan` or `apply` on the module under test and
  then evaluates its `assert` blocks. Runs execute **in order** and share
  state within the file.
* **`command = plan`** — assertions see planned values. Values that are only
  known after apply (IDs, URLs) are unknown and can't be asserted.
* **`command = apply`** (the default) — creates real resources (unless the
  provider is mocked), then asserts. At the end of the file, Terraform
  **destroys** everything the file created, in reverse order.
* **`variables`** blocks at file level or inside a run set input variables.
* **`assert`** blocks have a `condition` and an `error_message`, like custom
  conditions (Chapter 8). Assertions can refer to resources, data sources,
  outputs (`output.url`), and variables of the module.

### Testing that bad input fails: `expect_failures`

A good module rejects invalid input. Test that the validation fires:

```hcl
run "rejects_unknown_environment" {
  command = plan

  variables {
    environment = "qa"
  }

  expect_failures = [
    var.environment,
  ]
}
```

The run **passes** if the listed checkable objects (variables with
validations, resources with pre/postconditions, outputs, check blocks) fail,
and fails if they don't.

### Referencing earlier runs and helper modules

A run can use outputs from a previous run with `run.<name>.<output>`, and it
can execute a **different module** with a `module` block — handy for setup
or verification helpers:

```hcl
run "service_returns_200" {
  command = plan

  module {
    source = "./tests/http-check"     # a small helper module with a data "http"
  }

  variables {
    url = run.service_responds.url    # output of the previous run
  }

  assert {
    condition     = data.http.service.status_code == 200
    error_message = "The service did not return HTTP 200."
  }
}
```

### Useful flags

| Flag | Purpose |
|---|---|
| `-filter=tests/unit.tftest.hcl` | Run only some test files. |
| `-verbose` | Print the plan/state of each run. |
| `-var` / `-var-file` | Set variables for the tests. |
| `-test-directory=DIR` | Use a different folder than `tests/`. |
| `-junit-xml=FILE` | Write results for CI test reports. |

## 19.5 Unit tests without the cloud: mocks

Plans against the real Google provider still need credentials (the provider
configures itself and data sources call APIs). **Mock providers** replace a
provider with a fake that returns generated values, so tests run anywhere —
on a laptop with no login, or in a CI job with no cloud access — and
`command = apply` creates nothing real.

```hcl
mock_provider "google" {
  # Give computed attributes realistic values instead of random strings.
  mock_resource "google_cloud_run_v2_service" {
    defaults = {
      uri = "https://dev-web-shop-abc123-ew.a.run.app"
    }
  }

  mock_resource "google_service_account" {
    defaults = {
      email = "dev-web-shop@test-project.iam.gserviceaccount.com"
    }
  }
}

run "outputs_use_computed_values" {
  command = apply      # "applies" against the mock: nothing is created

  assert {
    condition     = output.url == "https://dev-web-shop-abc123-ew.a.run.app"
    error_message = "The url output should expose the service URI."
  }
}
```

* Without `defaults`, computed string attributes get random values, numbers
  get 0, and so on.
* `mock_data "<type>" { defaults = { ... } }` does the same for data sources.
* **Overrides** replace a single resource, data source, or module in a test:

  ```hcl
  override_data {
    target = data.google_compute_zones.available
    values = {
      names = ["europe-west1-b", "europe-west1-c"]
    }
  }

  override_module {
    target  = module.network
    outputs = { subnet_id = "projects/p/regions/r/subnetworks/s" }
  }
  ```

  Overrides can be placed at file level or inside a single `run`.

Mocks test **your logic** (names, conditionals, loops, validations, wiring),
not whether Google accepts the configuration. That's what integration tests
are for.

## 19.6 Integration tests: real resources

Integration tests use the real provider and `command = apply`:

```hcl
variable "project_id" {
  description = "Project to create the test resources in."
  type        = string
}

provider "google" {
  project = var.project_id
  region  = "europe-west1"
}

variables {
  region      = "europe-west1"
  environment = "dev"
  app_name    = "tftest" # avoid clashing with real environments
}

run "service_responds" {
  command = apply

  assert {
    condition     = startswith(output.url, "https://")
    error_message = "The service did not get an https URL."
  }
}
```

The `variable "project_id"` block declares a variable that is used only in
the test file (the provider block needs it). Without it, Terraform 1.17
reads the value from `TF_VAR_project_id` as an expression, so
`tf-book-fatih-12345` looks like a subtraction and the test fails with
`Variables not allowed`.

```console
$ TF_VAR_project_id=tf-book-fatih-12345 terraform test -filter=tests/integration.tftest.hcl
tests/integration.tftest.hcl... in progress
  run "service_responds"... pass
  run "service_returns_200"... pass
tests/integration.tftest.hcl... tearing down
tests/integration.tftest.hcl... pass
```

Best practices:

* Use a **dedicated test project** so tests can't touch real environments.
* Use unique names (`app_name = "tftest"`, or a random suffix).
* Keep them focused: one module, a few assertions.
* If a test is interrupted, resources may remain — clean the test project
  regularly.

**Terratest** is a popular Go library for more complex integration tests
(HTTP checks, SSH, retries). The native framework covers most module needs
without another language.

## 19.7 Pre-commit hooks

Catch problems before they're even committed. With
[pre-commit](https://pre-commit.com) and the community hooks from
`antonbabenko/pre-commit-terraform`:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.109.3
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
```

```console
$ pip install pre-commit
$ pre-commit install            # once per clone
$ git commit -m "Add bucket"   # hooks run automatically
terraform fmt............................................................Passed
terraform validate.......................................................Passed
terraform tflint.........................................................Passed
```

Pre-commit is a convenience for developers. The **CI pipeline** (Chapters
21 – 22) must run the same checks, because hooks can be skipped.

## Common mistakes and tips

* Asserting on values that are unknown during `plan` (IDs, URLs) — use mocks
  with `command = apply`, or a real `apply`.
* Forgetting `terraform init` before `terraform test` (tests need providers
  and helper modules).
* Running integration tests in a shared or production project.
* Treating mocks as proof that Google accepts the configuration — they don't
  talk to Google.
* Only testing the "happy path" — test validations with `expect_failures`.

## Summary

* Test at several levels: static checks on every commit, unit tests with
  plans and mocks, integration tests with real resources when needed.
* TFLint with the Google ruleset finds errors `validate` can't.
* `terraform test` uses `.tftest.hcl` files with `run`, `assert`,
  `variables`, `expect_failures`, helper `module`s, and `run.<name>` outputs.
* `mock_provider`, `mock_resource`, and `override_*` make tests fast, free, and
  credential-free.
* Pre-commit hooks give fast local feedback; CI enforces the same checks.

## Quick check

1. What's the difference between `command = plan` and `command = apply` in a
   run block?
2. How do you test that an invalid `environment` value is rejected?
3. What does `mock_provider "google"` do, and what does it *not* prove?
4. Name a mistake TFLint's Google ruleset can catch that `terraform validate`
   cannot.
5. Why must CI repeat the checks that pre-commit hooks run?

---

## Hands-on exercise: Test the web-app module

**Goal:** Lint the `web-app` module from Chapter 18 and write unit tests that
run without credentials, then optionally an integration test.

**Estimated time:** 30 minutes

**Files:** `code/ch19-testing/exercise/` (the module is in `web-app/`)

### Steps

1. **Static checks.** In `code/ch19-testing/exercise`:

   ```console
   $ cd web-app
   $ terraform fmt -check -recursive
   $ terraform init -backend=false
   $ terraform validate
   $ tflint --init --config ../.tflint.hcl
   $ tflint --config ../.tflint.hcl
   ```

2. **Break it on purpose.** Add a variable `unused` to `variables.tf` and run
   TFLint again. Read the warning, then remove the variable.
3. **Unit tests.** Open `tests/unit.tftest.hcl`. The first run is written for
   you. Complete the `TODO`s:
   * assert the bucket name,
   * test public access prevention, uniform access, and labels,
   * test that `public = false` removes the `allUsers` binding,
   * test the `url` output using the mocked URI with `command = apply`,
   * test that invalid `environment` and `max_instances` values fail
     (`expect_failures`).
4. Run the tests **logged out** to prove they need no credentials:

   ```console
   $ terraform test -filter=tests/unit.tftest.hcl
   ```

   To be sure no credentials are used, you can also point the Google
   libraries at locations that don't exist:

   ```console
   $ CLOUDSDK_CONFIG=/tmp/empty GOOGLE_APPLICATION_CREDENTIALS=/nonexistent \
       terraform test -filter=tests/unit.tftest.hcl
   ```
5. **Make a test fail.** Change the bucket's `public_access_prevention` to
   `"inherited"` in `main.tf` and rerun the tests. Read the failure message.
   Revert.
6. **Integration test (optional, creates real resources for ~2 minutes).**

   ```console
   $ TF_VAR_project_id=<your-project-id> terraform test -filter=tests/integration.tftest.hcl
   ```

7. **Pre-commit (optional).** Initialise a Git repository in the exercise
   folder, `pip install pre-commit`, `pre-commit install`, and commit. Watch
   the hooks run.

### Expected result

`Success! 7 passed, 0 failed.` for the unit tests, without any Google Cloud
credentials.

### Stretch goal

Add a run that sets `deletion_protection = true` and asserts that the bucket's
`force_destroy` is `false`.

### Cleanup

Unit tests create nothing. The integration test destroys its resources
automatically; check with `gcloud run services list` that no `dev-tftest`
service remains.

---

## Quick check answers

1. `plan` only plans and asserts on planned values (no resources created);
   `apply` creates the resources (real or mocked), asserts, and destroys them
   at the end of the test file.
2. A run with `variables { environment = "qa" }` and
   `expect_failures = [var.environment]`.
3. It replaces the real provider with a fake that returns generated or
   configured values, so no credentials are needed and nothing is created. It
   doesn't prove that the real Google API would accept the configuration.
4. For example an invalid machine type (`e2-mikro`), invalid region, or other
   provider-specific values.
5. Hooks run locally and can be skipped or not installed; only CI guarantees
   every change is checked.
