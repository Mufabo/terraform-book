# Chapter 22 — Capstone Project and Exam Preparation

## Learning objectives

By the end of this lesson you will be able to:

* Combine everything from this book into one production-style Terraform
  project on Google Cloud.
* Explain each design decision in that project (modules, environments, state,
  secrets, testing, policies, pipelines).
* Describe the format of the Terraform Associate (004) exam and plan your
  preparation.
* Check your readiness against every exam objective.
* Answer exam-style questions under time pressure.

---

## Part A — The capstone project

### A.1 What you're building

The **web-shop platform**: a containerised web application on Cloud Run,
deployed to **dev** and **prod**, with its own network, secrets, tests,
policies, and a fully automated pipeline.

```
GitHub repository: web-shop-infra
│
├── PR opened ──▶ fmt · tflint · terraform test (mocked)
│                 plan dev + prod (read-only identity) · gcloud terraform vet
│                 plan comment on PR
│
└── merge ──────▶ dev: plan · vet · apply (automatic)
                  prod: ⏸ approval · plan · vet · apply

Each environment (own state under gs://<bucket>/envs/<env>/):
┌────────────────────────────────────────────────────────────────────┐
│ module "network"   VPC + subnet (Private Google Access)            │
│ Secret Manager     <env>-web-shop-api-key (write-only, not in state)│
│ module "web_app"   service account · uploads bucket (private)      │
│                    Cloud Run service ── Direct VPC egress ─▶ subnet │
│                      API_KEY ◀── secret_key_ref                     │
└────────────────────────────────────────────────────────────────────┘
```

### A.2 Requirements

The full requirement list is in `code/ch22-capstone/exercise/README.md`. In
short:

1. A new `network` module and an extended `web-app` module (Direct VPC
   egress, secrets from Secret Manager), each with mocked unit tests.
2. `dev` and `prod` root modules with separate state, pinned providers, and
   a secret generated with an **ephemeral** resource and stored with a
   **write-only** argument.
3. Quality gates: `fmt`, TFLint, `terraform test`, `gcloud terraform vet`
   with at least one constraint you wrote yourself.
4. Delivery through GitHub Actions with a production approval (a public
   repository, or a paid plan; see Chapter 21).
5. A README.

Plan for **two to three hours** — this is the one chapter that's longer than
an hour. Work in small pull requests; let your pipeline check every step.

### A.3 Suggested order

1. Copy your Chapter 21 repository (or `code/ch21-github-actions/solution/repo`).
2. Write `infra/modules/network`; add it to `envs/dev` only; open a PR and let
   the pipeline plan it; merge.
3. Extend `web-app` with `subnet_id` (dynamic `vpc_access` block). Write the
   unit test first, watch it fail, implement, watch it pass.
4. Add `secret_env`, the IAM binding per secret, and a test.
5. Add the secret (ephemeral `random_password` + `secret_data_wo`) to
   `envs/dev`, wire it into the module. PR, merge, verify dev.
6. Repeat for `envs/prod`. Approve the prod deployment.
7. Write your own policy constraint and prove it catches a violation in a PR.
8. Write the README.

### A.4 Design review — explain your choices

When you've finished, answer these questions in your README. They're the same
questions a senior engineer would ask in a design review, and they revise the
whole book:

| Question | Where you learned it |
|---|---|
| Why is each environment a separate root module rather than a CLI workspace? | Ch. 18 |
| Where is state stored, how is it locked, how is it protected? | Ch. 9–10 |
| Why are provider versions pinned exactly and module versions local? | Ch. 4, 12 |
| How does the API key avoid ever being written to state? | Ch. 14 |
| Why does the Cloud Run service `depends_on` the secret version and IAM binding? | Ch. 5 |
| What do the unit tests prove, and what can't they prove? | Ch. 19 |
| Which policy would have caught a public bucket, and at what point in the pipeline? | Ch. 20 |
| How does the pipeline authenticate, and why can't a pull request deploy to prod? | Ch. 21 |
| How would you detect someone changing the service in the console? | Ch. 11, 21 |
| What would you change to move prod into its own Google Cloud project? | Ch. 18 |

### A.5 Reference solution

`code/ch22-capstone/solution/` contains a complete, validated solution:

```
solution/
├── .github/workflows/          # GitHub Actions (Chapter 21)
├── bootstrap-github/           # WIF + service accounts for GitHub Actions
├── policy-library/             # Chapter 20 policies
├── .tflint.hcl
└── infra/
    ├── modules/
    │   ├── network/
    │   └── web-app/            # with tests/unit.tftest.hcl (9 tests)
    └── envs/
        ├── dev/
        └── prod/
```

---

## Part B — Preparing for the Terraform Associate (004) exam

### B.1 The exam at a glance

| | |
|---|---|
| Name | HashiCorp Certified: Terraform Associate (004) |
| Format | Multiple choice — single answer, multiple answers, true/false, and similar |
| Duration | 1 hour |
| Delivery | Online, proctored |
| Product version | Terraform 1.12 (concepts tested apply equally to 1.17) |
| Provider knowledge | Not required — the exam is cloud-agnostic |
| Price, languages, validity | Check the official page — these change |

Official resources:

* Exam page: <https://developer.hashicorp.com/certifications/infrastructure-automation>
* Exam content list (objectives with links):
  <https://developer.hashicorp.com/terraform/tutorials/certification-004/associate-review-004>

### B.2 A two-week study plan

| Days | Activity |
|---|---|
| 1–2 | Re-read the summaries and "Common mistakes and exam tips" of Chapters 1–8. Redo the quick checks without looking. |
| 3–4 | Chapters 9–15 the same way. Re-run the Chapter 9 and 11 exercises — state and import questions are common. |
| 5 | Chapters 16–17 (HCP Terraform). If you skipped the exercises, at least create a free organisation and click through workspaces, variables, variable sets, the registry, and policy sets. |
| 6 | Walk through Appendix A. Mark every objective you can't explain out loud in two sentences. |
| 7 | Take the practice test below (Part C) under exam conditions: 30 questions, 30 minutes. |
| 8–11 | Study your marked objectives. Read the official documentation pages linked from the exam content list. |
| 12 | Memorise the cheat sheet (Appendix B): commands, flags, precedence, `~>`. |
| 13 | Retake the practice test; review every wrong answer *and* every guess. |
| 14 | Rest. Check your exam setup (ID, webcam, quiet room). |

### B.3 Topics that trip people up

* **`~>` constraints** — `~> 1.2.0` vs `~> 1.2`.
* **Variable precedence** — CLI `-var` > `*.auto.tfvars` > `terraform.tfvars`
  > `TF_VAR_` > default.
* **`sensitive` doesn't keep values out of state.**
* **`terraform state rm` doesn't destroy anything.**
* **Lock file pins providers, not modules.**
* **Module `version` only works with registry sources.**
* **Child modules can't see parent variables.**
* **`check` blocks warn; validations/pre/postconditions error.**
* **`-refresh-only`** is the modern replacement for `terraform refresh`;
  **`-replace`** replaces `taint`.
* **HCP Terraform workspaces ≠ CLI workspaces.**
* **Sentinel enforcement levels**: advisory, soft-mandatory (overridable),
  hard-mandatory.
* **`TF_LOG` levels** and `TF_LOG_PATH`.
* **What `init` does** (backend, providers + lock file, modules).

### B.4 Exam technique

* Read the **whole** question — words like *not*, *best*, *first*, and
  *choose two* matter.
* Eliminate obviously wrong answers first.
* If an answer mentions a specific cloud provider's feature, it's probably a
  distractor — the exam is provider-agnostic.
* Mark difficult questions and come back; don't spend more than ~90 seconds
  on one question in the first pass.
* There's no penalty for guessing — answer everything.

---

## Part C — Practice test

30 questions, 30 minutes. Write down your answers, then check them in
Part D. Questions marked *(choose two)* have exactly two correct answers.

**1.** Which of the following are benefits of Infrastructure as Code?
*(choose two)*
A. Infrastructure changes can be reviewed and versioned like application code
B. It removes the need for cloud provider APIs
C. Environments can be recreated consistently
D. It guarantees that infrastructure never fails

**2.** What does `terraform init` **not** do?
A. Download provider plugins
B. Initialise the backend
C. Create the resources defined in the configuration
D. Download modules

**3.** A configuration contains `version = "~> 3.4.0"` for a provider. Which
version may Terraform install?
A. 3.5.0  B. 3.4.7  C. 4.0.0  D. 3.3.9

**4.** Which file should be committed to version control so that everyone uses
the same provider versions?
A. `terraform.tfstate`  B. `.terraform/`  C. `.terraform.lock.hcl`
D. `terraform.tfvars`

**5.** You need resources in two Google Cloud regions using the same provider.
What do you use?
A. Two `required_providers` blocks
B. A second `provider` block with an `alias`, selected by the `provider`
meta-argument
C. Two separate state files
D. The `depends_on` meta-argument

**6.** Which command checks a configuration for syntax errors and internal
consistency without contacting any remote services?
A. `terraform plan`  B. `terraform validate`  C. `terraform fmt -check`
D. `terraform show`

**7.** In a plan, what does the symbol `-/+` mean?
A. The resource will be updated in place
B. The resource will be destroyed and re-created
C. The resource will be read
D. The resource will be imported

**8.** You run `terraform apply tfplan` with a saved plan file. What happens?
A. Terraform asks for confirmation before applying
B. Terraform applies the plan without asking for confirmation
C. Terraform creates a new plan and ignores the file
D. Terraform only shows the plan

**9.** What is the difference between a `resource` block and a `data` block?
A. `data` blocks create resources faster
B. `resource` blocks manage infrastructure; `data` blocks read existing
information
C. `data` blocks are only for databases
D. There is no difference

**10.** Resource B needs resource A to exist but does not reference any of
A's attributes. How do you make Terraform create A first?
A. Put A above B in the file
B. Use `depends_on = [A]` in B
C. Use `count`
D. Use `lifecycle { create_before_destroy = true }`

**11.** A variable is set in `terraform.tfvars` to `"a"`, in the environment
as `TF_VAR_x=b`, and on the command line with `-var x=c`. Which value is used?
A. a  B. b  C. c  D. The default value

**12.** Which type allows elements of different types at fixed positions?
A. `list`  B. `set`  C. `map`  D. `tuple`

**13.** What does `for_each` accept? *(choose two)*
A. A map
B. A set of strings
C. A number
D. A list of objects (directly)

**14.** Which is true about `check` blocks?
A. A failing assertion stops the apply
B. A failing assertion produces a warning, and the operation continues
C. They can only be used inside modules
D. They replace variable validation

**15.** Which lifecycle argument prevents a resource from being destroyed by
Terraform?
A. `ignore_changes`  B. `create_before_destroy`  C. `prevent_destroy`
D. `replace_triggered_by`

**16.** A database password is marked `sensitive = true` in an output. Where
can the password still be found in plain text?
A. Nowhere
B. In the state file
C. Only in HCP Terraform
D. In the `.terraform.lock.hcl` file

**17.** What is the main purpose of state locking?
A. Encrypting the state
B. Preventing concurrent operations from corrupting the state
C. Making the state read-only forever
D. Speeding up plans

**18.** What does `terraform state rm aws_instance.web` do?
A. Destroys the instance and removes it from state
B. Removes the instance from state without destroying it
C. Renames the instance
D. Locks the instance

**19.** Which statements about backend configuration are true? *(choose two)*
A. Variables can be used inside the `backend` block
B. Backend settings can be supplied at init time with `-backend-config`
C. Changing the backend requires re-running `terraform init`
D. The backend configuration is stored in the state file

**20.** Someone changed a resource manually. Which command updates the state
to match reality without changing infrastructure?
A. `terraform apply -refresh-only`
B. `terraform apply -replace`
C. `terraform import`
D. `terraform force-unlock`

**21.** Which statements about `import` blocks are true? *(choose two)*
A. They require `to` and `id`
B. They create the resource in the cloud
C. Combined with `terraform plan -generate-config-out=FILE`, Terraform can
write configuration for imported resources
D. They can only be used with the local backend

**22.** You renamed a resource in your configuration. How do you avoid
Terraform destroying and re-creating it?
A. Add a `moved` block
B. Add `ignore_changes = all`
C. Run `terraform refresh`
D. Delete the state file

**23.** Which environment variable enables detailed Terraform logs?
A. `TF_DEBUG`  B. `TF_LOG`  C. `TF_VERBOSE`  D. `TF_TRACE`

**24.** How do you pin a module from a Git repository to a specific release?
A. `version = "1.2.0"` in the module block
B. `?ref=v1.2.0` in the `source` URL
C. The lock file pins it automatically
D. It's not possible

**25.** Inside a child module, how do you use a value defined in the root
module?
A. Reference `var.<name>` directly — child modules inherit root variables
B. Declare an input variable in the child and pass the value in the `module`
block
C. Use `terraform_remote_state`
D. Use a `locals` block in the root

**26.** Which source address refers to a module in an HCP Terraform private
registry?
A. `hashicorp/consul/aws`
B. `app.terraform.io/example-corp/vpc/google`
C. `./modules/vpc`
D. `git::https://example.com/vpc.git`

**27.** Which Sentinel enforcement level allows an authorised user to override
a failed policy?
A. advisory  B. soft-mandatory  C. hard-mandatory  D. mandatory

**28.** What is true about HCP Terraform workspaces?
A. They are identical to CLI workspaces
B. Each workspace has its own state, variables, and permissions
C. All workspaces in an organisation share one state file
D. They can only be used with VCS-driven runs

**29.** Which block connects a configuration to HCP Terraform?
A. `backend "hcp"`  B. `cloud`  C. `provider "tfe"`  D. `remote_state`

**30.** HCP Terraform runs a plan when a pull request is opened against a
connected repository. What kind of run is this?
A. A destroy run
B. A speculative plan that cannot be applied
C. A refresh-only run
D. An apply run

---

## Part D — Answers and explanations

| # | Answer | Explanation | Chapter |
|---|---|---|---|
| 1 | A, C | IaC enables versioning, review, and consistent re-creation. It still uses APIs and doesn't prevent failures. | 1 |
| 2 | C | `init` prepares the directory; only `apply` creates resources. | 3 |
| 3 | B | `~> 3.4.0` = `>= 3.4.0, < 3.5.0`. | 4 |
| 4 | C | The lock file records provider versions and checksums. State and tfvars may contain secrets; `.terraform/` is downloaded content. | 3, 4 |
| 5 | B | Aliased provider configurations, selected per resource with `provider = google.alias`. | 4 |
| 6 | B | `validate` checks syntax and consistency locally. `fmt -check` only checks formatting. | 3 |
| 7 | B | Destroy then create (replacement). | 3 |
| 8 | B | Saved plans apply without confirmation (and fail if stale). | 3 |
| 9 | B | Resources are managed; data sources are read-only. | 5 |
| 10 | B | Hidden dependencies need `depends_on`. File order doesn't matter. | 5 |
| 11 | C | Command-line `-var` has the highest precedence. | 6 |
| 12 | D | Tuples have fixed positions with individual types. | 6 |
| 13 | A, B | `for_each` takes a map or a set of strings; convert lists with `toset()` or a `for` expression into a map. | 7 |
| 14 | B | Check blocks only warn. | 8 |
| 15 | C | `prevent_destroy` makes any destroying plan fail. | 8 |
| 16 | B | `sensitive` only redacts CLI output; the value is in state. | 9, 14 |
| 17 | B | Locking prevents concurrent writes. | 9 |
| 18 | B | `state rm` only forgets the object. | 9 |
| 19 | B, C | Variables aren't allowed in backends; backend config isn't stored in state; partial configuration and re-init are correct. | 10 |
| 20 | A | Refresh-only apply updates state to reality. | 11 |
| 21 | A, C | `import` blocks need `to` and `id` and can generate config; they don't create resources and work with any backend. | 11 |
| 22 | A | `moved` blocks record renames declaratively. | 11 |
| 23 | B | `TF_LOG` (with `TF_LOG_PATH` for a file). | 15 |
| 24 | B | `?ref=` selects a Git tag/branch/commit; `version` is for registry sources. | 12 |
| 25 | B | Modules have their own scope; pass values through input variables. | 13 |
| 26 | B | Private registry sources include the hostname and organisation. | 17 |
| 27 | B | Soft-mandatory failures can be overridden. | 17 |
| 28 | B | HCP Terraform workspaces are full entities with their own state, variables, and permissions. | 16 |
| 29 | B | The `cloud` block (older: `backend "remote"`). | 16 |
| 30 | B | PRs trigger speculative plans, which can't be applied. | 16 |

**Scoring:** 24 or more correct → you're likely ready. 18–23 → review the
chapters of the questions you missed. Below 18 → work through the study plan
in B.2 before booking.

---

## Hands-on exercise

The capstone project in Part A *is* this chapter's exercise. Work through the
requirements in `code/ch22-capstone/exercise/README.md`, then compare with
`code/ch22-capstone/solution/`.

### Cleanup

When you're finished with the book, delete everything:

1. Destroy prod (set `deletion_protection = false` and apply first), then dev.
   The first `destroy` usually stops at the subnet with
   `resourceInUseByAnotherResource` on a `serverless-ipv4-cloudrun-...`
   address: Cloud Run's Direct VPC egress reserves these addresses, and
   Google releases them only some time after the service is deleted (allow
   an hour or two). Run `terraform destroy` again later; everything except
   the network is already gone.
2. Destroy the bootstrap configurations (Chapters 16, 21, 22).
3. Delete leftover resources from Appendix C's checklist.
4. Optionally **shut down the whole learning project**:

   ```console
   $ gcloud projects delete $PROJECT_ID
   ```

   Everything in the project is deleted (recoverable for 30 days).

Congratulations — you've gone from your first `terraform init` to a tested,
policy-checked, multi-environment platform deployed by keyless pipelines. Good
luck with the exam!
