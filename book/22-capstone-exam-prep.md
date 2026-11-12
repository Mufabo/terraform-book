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

**Time:** 3½ to 4½ hours — about 15 minutes of reading (Parts A and B), 2 to
3 hours for the capstone project, and 40 minutes for each of the two practice
tests with its review.

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

> [!NOTE]
> **Google Cloud: Direct VPC egress and Private Google Access.** A Cloud Run
> service doesn't live in your VPC network. **Direct VPC egress** gives it a
> network interface in a subnet, so its outgoing traffic can reach private
> addresses in the network, such as a database with a private IP. **Private
> Google Access** is a subnet setting that lets resources without external IP
> addresses still reach Google APIs (Cloud Storage, Secret Manager, ...).
> Together they let the service use private resources without a public path.

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

Plan for **two to three hours** — far more than any other chapter. Work in
small pull requests; let your pipeline check every step.

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
| Why does the Cloud Run service `depends_on` the IAM binding, and the `web_app` module call on the secret version? | Ch. 5 |
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
| 1–2 | Re-read the summaries and "Common mistakes and exam tips" of Chapters 1–8. Redo the quick checks and the reviews of Parts I and II without looking. |
| 3–4 | Chapters 9–15 and the reviews of Parts III and IV the same way. Re-run the Chapter 9 and 11 exercises — state and import questions are common. |
| 5 | Chapters 16–17 (HCP Terraform). If you skipped the exercises, at least create a free organisation and click through workspaces, variables, variable sets, the registry, and policy sets. |
| 6 | Walk through Appendix A. Mark every objective you can't explain out loud in two sentences. |
| 7 | Take the first practice test (Part C) under exam conditions: 30 questions, 30 minutes. |
| 8–11 | Study your marked objectives. Read the official documentation pages linked from the exam content list. |
| 12 | Memorise the cheat sheet (Appendix B): commands, flags, precedence, `~>`. |
| 13 | Take the second practice test (Part E), which is scenario-based. Review every wrong answer *and* every guess. |
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

## Part C — First practice test

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

## Part D — Answers to the first test

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

## Part E — Second practice test: scenarios

30 questions, 30 minutes. These are harder than Part C: most describe a
situation and ask what happens or what you would do, which is how many
questions in the real exam are written. Questions marked *(choose two)* have
exactly two correct answers. Take this test only after you have reviewed your
mistakes from Part C.

**1.** A start-up's infrastructure was built in the console by one engineer,
who has left. Nobody can rebuild the staging environment or say who changed
what. Which IaC benefits address this directly? *(choose two)*

* A. Lower prices from the cloud provider
* B. The code documents what exists, and environments can be re-created from
  it
* C. There is no longer any need for access control
* D. Every change is recorded in version control with an author and a reason

**2.** A company manages GitHub repositories, Cloudflare DNS records, and
Google Cloud resources. Which statement describes how Terraform handles this?

* A. One configuration can use several providers, and values can pass between
  their resources
* B. Each platform needs its own IaC tool
* C. A state file can hold resources of only one provider
* D. Several providers require HCP Terraform

**3.** A lock file was committed from a Linux machine. Whenever a colleague on
macOS runs `terraform init`, Git shows the lock file as changed. What stops
this from recurring?

* A. Add `.terraform.lock.hcl` to `.gitignore`
* B. Run `terraform init -upgrade` on every machine
* C. Run `terraform providers lock` with a `-platform` flag for each platform
  in use and commit the result
* D. Delete the lock file in CI

**4.** A root module requires the Google provider `>= 8.0`. A child module it
calls requires `>= 7.0, < 9.0`. Versions 8.9.0 and 9.1.0 are available, and
there is no lock file. Which version does `terraform init` select?

* A. 9.1.0
* B. 7.0.0
* C. None; the constraints conflict
* D. 8.9.0

**5.** A resource of type `google_compute_network` must be created with the
`google-beta` provider. Both providers are declared and configured. How do you
select it?

* A. Rename the resource type to `google-beta_compute_network`
* B. Add `provider = google-beta` to the resource
* C. Nothing; Terraform chooses the beta provider when needed
* D. Declare an alias; without one it's impossible

**6.** You delete a resource block from the configuration. The next `terraform
apply` destroys the real object. How did Terraform know that the object
existed, and which provider manages it?

* A. It asked the cloud for a list of all resources
* B. It read the Git history
* C. It read the dependency lock file
* D. The state records the object, its provider, and its dependencies

**7.** A CI job should run `terraform validate` on a configuration that uses a
`gcs` backend. The job has no credentials for the state bucket. What do you
run first?

* A. `terraform init -backend=false`
* B. `terraform init -reconfigure`
* C. `terraform plan -refresh=false`
* D. Nothing; `validate` needs no `init`

**8.** A script runs `terraform plan -detailed-exitcode` and receives exit
code 2. What does that mean?

* A. The plan failed with an error
* B. The saved plan is stale
* C. The plan succeeded and there are changes to apply
* D. The plan succeeded and there is nothing to change

**9.** An apply creates five resources. The third fails because a quota is
exhausted. What is the situation afterwards?

* A. Terraform rolled back the first two resources
* B. The first two resources exist and are recorded in state; after fixing the
  cause, another apply continues
* C. The state file is corrupt and must be restored
* D. Everything must be destroyed before trying again

**10.** One of twenty resources in a configuration is no longer needed. What
is the normal way to remove it?

* A. Run `terraform destroy`
* B. Run `terraform state rm` for it
* C. Run `terraform destroy -target` for it and leave the code as it is
* D. Delete its block from the configuration and apply

**11.** A VM is declared with `image =
"data.google_compute_image.debian.self_link"`. The apply fails because the
image is invalid. What is wrong?

* A. The data source needs `depends_on`
* B. The reference is in quotes, so the literal text is sent as the image name
* C. Data sources have no `self_link` attribute
* D. The `data.` prefix is not allowed in arguments

**12.** A variable has no default. A pipeline runs `terraform plan
-input=false` without setting it anywhere. What happens?

* A. Terraform asks for the value interactively
* B. The value is `null`
* C. The plan fails: no value for a required variable
* D. The value is an empty string

**13.** A variable is declared as `set(string)`. The code uses `var.zones[0]`.
What is the result?

* A. An error: sets have no order and can't be indexed
* B. The first element in alphabetical order
* C. A random element
* D. `null`

**14.** What does `[for k, v in { a = 1, b = 2 } : "${k}=${v}" if v > 1]`
evaluate to?

* A. `["a=1", "b=2"]`
* B. `{ b = 2 }`
* C. An error
* D. `["b=2"]`

**15.** A firewall rule is created with `count = var.enable_ssh ? 1 : 0`. An
output should return the rule's name, or `null` when the rule doesn't exist.
Which expression works in both cases?

* A. `google_compute_firewall.ssh.name`
* B. `google_compute_firewall.ssh[0].name`
* C. `one(google_compute_firewall.ssh[*].name)`
* D. `google_compute_firewall.ssh[count.index].name`

**16.** Which of these stop a plan or apply with an **error** when their
condition is false? *(choose two)*

* A. A `validation` block in a variable
* B. An `assert` in a `check` block
* C. The `description` of an output
* D. A `postcondition` in a resource's `lifecycle` block

**17.** Which of these keep a secret's value out of the Terraform state?
*(choose two)*

* A. `sensitive = true` on the variable
* B. An ephemeral resource whose result goes into a write-only argument
* C. `sensitive = true` on the output
* D. Letting the application read the secret from a secret manager at runtime,
  so Terraform never handles the value

**18.** A configuration reads a database password from Vault with an ordinary
data source and passes it to a resource's `password` argument. Where is the
password afterwards, besides Vault and the database?

* A. Nowhere else
* B. In the dependency lock file, encrypted
* C. In the provider's cache directory
* D. In the state (and in saved plan files) in plain text

**19.** What does `source = "github.com/acme/modules//network?ref=v1.2.0"`
select?

* A. The sub-directory `network` of the repository, at the tag `v1.2.0`
* B. A branch called `network`
* C. Two modules, `modules` and `network`
* D. Nothing; the double slash is a syntax error

**20.** A root module calls the modules `network` and `app`. `app` needs the
ID of a subnet that `network` creates. What is required? *(choose two)*

* A. `app` refers to `module.network.subnet_id` in its own code
* B. `network` declares an output for the subnet ID
* C. A `terraform_remote_state` data source in `app`
* D. The root passes `module.network.subnet_id` to an input variable of `app`

**21.** A module is called with `version = "~> 18.0"`. One engineer installed
it months ago and has 18.1.0. A new colleague clones the repository today,
when 18.3.1 is available, and gets different plans. What prevents this?

* A. Committing the `.terraform` directory
* B. The dependency lock file
* C. Pinning the module to an exact version
* D. Never running `terraform init -upgrade`

**22.** Two engineers each run `terraform apply` for the same project from
their own laptops, with the default local backend. What is the problem?

* A. The second apply waits for the first one's lock
* B. Each laptop has its own state file and its own lock, so they create
  duplicates or collide; they need a shared remote backend
* C. Nothing; Terraform merges the state files
* D. The second engineer's apply is always rejected

**23.** A configuration with existing local state gets a `backend "gcs"`
block. During `terraform init` the engineer answers **no** to copying the
existing state. What does the next `terraform plan` show?

* A. No changes
* B. An error about a missing state
* C. A plan to create every resource again, because the new backend's state is
  empty
* D. A plan to destroy every resource

**24.** A nightly job should detect drift and report it, without changing
infrastructure or state. Which command fits?

* A. `terraform plan -refresh-only -detailed-exitcode`
* B. `terraform apply -refresh-only -auto-approve`
* C. `terraform refresh`
* D. `terraform plan -destroy`

**25.** A VM's startup script failed halfway. The configuration hasn't
changed, and you want Terraform to re-create the VM. What do you run?

* A. `terraform state rm` for the VM, then `terraform apply`
* B. `terraform destroy`
* C. `terraform apply -refresh-only`
* D. `terraform apply -replace=<address>`

**26.** After importing a bucket, `terraform plan` shows in-place changes for
it. What does that tell you?

* A. The import failed
* B. The resource block doesn't match the real bucket's settings; adjust the
  configuration until the plan is clean, or accept the changes on purpose
* C. The state is corrupt
* D. Import always requires one corrective apply

**27.** A script needs the addresses of all resources in the state, and then
every attribute of one of them. Which commands does it use?

* A. `terraform output`, then `terraform console`
* B. `terraform providers`, then `terraform graph`
* C. `terraform state list`, then `terraform state show <address>`
* D. `terraform validate`, then `terraform show`

**28.** Terraform crashes with a panic during `terraform plan`. What helps the
maintainers diagnose it? *(choose two)*

* A. The `crash.log` file Terraform wrote
* B. The dependency lock file
* C. A log made with `TF_LOG=TRACE`
* D. Your `terraform.tfvars`

**29.** A workspace uses the VCS-driven workflow, and auto-apply is off. A
pull request is merged into the main branch. What happens?

* A. Nothing, until someone starts a run by hand
* B. A run plans the change and then waits for someone with permission to
  confirm the apply
* C. The change is applied immediately
* D. Only a speculative plan runs, which can't be applied

**30.** A team keeps a Google Cloud service account key in a sensitive
workspace variable. What is the more secure alternative in HCP Terraform?

* A. Dynamic provider credentials: each run gets short-lived credentials
  through OIDC and Workload Identity Federation
* B. The key in a `terraform.tfvars` file in the repository
* C. The key in a variable set that isn't marked sensitive
* D. A key that is rotated every year

---

## Part F — Answers to the second test

| # | Answer | Explanation | Chapter |
|---|---|---|---|
| 1 | B, D | Repeatability and version history. IaC doesn't change prices or replace IAM. | 1 |
| 2 | A | Service-agnostic workflow: one language and workflow, many providers in one configuration. | 1 |
| 3 | C | The lock file then holds the checksums for all platforms up front. It must stay in version control. | 4 |
| 4 | D | Terraform picks the newest version that satisfies the constraints of **all** modules. | 4, 12 |
| 5 | B | Resource types start with `google_` in both providers, so the `provider` meta-argument decides. | 4 |
| 6 | D | State maps configuration to real objects and keeps this metadata even after the code is gone. | 9 |
| 7 | A | `validate` needs the providers installed, but not the backend. | 3, 10 |
| 8 | C | 0 = no changes, 1 = error, 2 = changes present. | 3 |
| 9 | B | Terraform doesn't roll back. State reflects what was created, and the next apply does the rest. | 1, 3 |
| 10 | D | The configuration is the desired state. `destroy` removes everything, `state rm` leaves the object running, and `-target` is for exceptions. | 3 |
| 11 | B | A quoted reference is just a string. References are written without quotes. | 5 |
| 12 | C | Without a default the variable is required, and `-input=false` forbids the prompt. | 6 |
| 13 | A | Convert with `tolist()` (and `sort()` for a defined order), or declare a list. | 6, 7 |
| 14 | D | Square brackets produce a list; the `if` clause filters out `a`. | 7 |
| 15 | C | With zero instances `[0]` is an error; `one()` returns `null` for an empty list. | 7 |
| 16 | A, D | Validations, preconditions, and postconditions block. Check blocks only warn. | 8 |
| 17 | B, D | `sensitive` only hides values in CLI output; the state still contains them. | 14 |
| 18 | D | Values read by data sources and stored resource arguments are written to state. Vault's benefits don't change that; ephemeral resources do. | 14 |
| 19 | A | `//` separates the repository from a sub-directory; `?ref=` selects a tag, branch, or commit. | 12 |
| 20 | B, D | Siblings can't see each other. The parent wires an output of one into an input of the other. | 13 |
| 21 | C | The lock file covers providers only, so a fresh `init` takes the newest module version the constraint allows. | 12 |
| 22 | B | Local state isn't shared. A remote backend gives one state and locking across machines. | 9, 10 |
| 23 | C | The state stayed behind in the local file. Terraform now knows of no resources, although they exist. | 10 |
| 24 | A | A refresh-only **plan** changes nothing, and the exit code tells the job whether drift was found. The apply variant and `refresh` write the state. | 11 |
| 25 | D | `-replace` plans the re-creation and shows it before anything happens. `state rm` would leave the old VM running and collide with the new one. | 11 |
| 26 | B | Import only records the object in state. Any difference between your block and reality shows up as a planned change. | 11 |
| 27 | C | `state list` prints addresses; `state show` prints one resource's attributes. | 9 |
| 28 | A, C | The crash log holds the stack trace and a trace log shows what led to it. Redact secrets before sharing either. | 15 |
| 29 | B | Merges start a real run. Without auto-apply it stops after the plan (and policy checks) for confirmation. Speculative plans belong to pull requests. | 16 |
| 30 | A | No long-lived secret is stored at all; the run's identity is exchanged for temporary credentials. | 16 |

**Scoring:** 24 or more correct → you can handle scenario questions; book the
exam. 18–23 → for each miss, write down *why* the right answer is right and
why your answer isn't, then reread that chapter's "Common mistakes and exam
tips". Below 18 → the facts are there but applying them isn't yet: redo the
chapter challenges for your weakest objectives.

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
