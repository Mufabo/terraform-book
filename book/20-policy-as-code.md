# Chapter 20 — Policy as Code with `gcloud terraform vet`

## Learning objectives

By the end of this lesson you will be able to:

* Explain what **policy as code** is and where it fits in the Terraform
  workflow.
* Validate a Terraform plan against a **policy library** with
  `gcloud beta terraform vet`.
* Describe the structure of a policy library: **constraint templates**,
  **constraints**, and `lib/`.
* Distinguish **Terraform-based** (plan) constraints from **CAI-based**
  (Cloud Asset Inventory) constraints.
* Write your own constraint template in **Rego** and configure constraints.
* Use `terraform vet`'s exit codes to gate a CI/CD pipeline.
* Compare `gcloud terraform vet` with Sentinel/OPA in HCP Terraform and
  scanners such as Checkov and Trivy.

**Time:** about 1 hour — 25 reading, 5 quick check, 30 exercise.

---

## 20.1 Why policy as code?

Every organisation has rules for its cloud:

* "Data must stay in the EU."
* "No bucket may ever be public."
* "Every resource needs `environment` and `owner` labels for cost reports."
* "Cloud Run services must not be open to `allUsers` in production."

You could write these rules in a wiki and hope reviewers remember them. Or you
can write them as **code** that a machine checks on **every** change, before
anything is deployed. That's **policy as code**:

* Rules are **versioned and reviewed** like any other code.
* Checks are **automatic and consistent** — no tired reviewer misses one.
* Violations are found **before** deployment, with a clear message.
* Security and compliance teams own the policies; application teams get fast
  feedback.

Where policy checks run:

```
 write code → fmt/validate/tflint → plan → POLICY CHECK → (approval) → apply
                                              ▲
                     gcloud terraform vet / Sentinel / OPA
```

Policies check the **plan**, because the plan contains the final, resolved
values (after variables, modules, and functions) of every resource that will
be created or changed.

Chapter 17 showed policy as code in HCP Terraform (Sentinel and OPA). This
chapter uses a Google Cloud–native tool that works with **any** Terraform
workflow, including the GitHub Actions pipeline in the next chapter:
**`gcloud beta terraform vet`**.

> **Note:** As the `beta` in the command suggests, `terraform vet` is a
> **Preview** (pre-GA) feature. It is supported and actively documented, but
> it comes with limited support and its behaviour may change between gcloud
> releases. That's one more reason to pin the gcloud version, as this book does.

## 20.2 How `gcloud terraform vet` works

`gcloud beta terraform vet` takes a Terraform plan in JSON format and a
**policy library** directory, and reports violations:

```console
$ terraform plan -out=tfplan
$ terraform show -json tfplan > tfplan.json
$ gcloud beta terraform vet tfplan.json --policy-library=./policy-library
```

Under the hood it does three things:

1. **Converts** the planned resources into **Cloud Asset Inventory (CAI)**
   format — the same format Google uses to describe assets in your
   organisation. For resources that already exist (and for IAM policies), it
   reads current values from Google Cloud with your credentials, so it can
   evaluate the *final* state, including the resource's position in the
   organisation hierarchy (its **ancestry**).
2. Validates the **CAI assets** against **CAI-based constraints**.
3. Validates the **raw plan resource changes** against **Terraform-based
   constraints**.

It's built on Google's open-source *Config Validator* and the Constraint
Framework from the Kubernetes Gatekeeper project. The policies are written in
**Rego**, the language of Open Policy Agent.

> [!NOTE]
> **Google Cloud: Cloud Asset Inventory.** **Cloud Asset Inventory** keeps a
> searchable record of every resource and IAM policy in a project, folder, or
> organization. Each record is an *asset* with a type such as
> `storage.googleapis.com/Bucket`, its full configuration, and its
> **ancestry**, the path up the resource hierarchy
> (`organizations/123/folders/456/projects/789`). Security teams use it to
> answer questions such as "which buckets in the company are public?"; try
> `gcloud asset search-all-resources --scope=projects/$PROJECT_ID`.
> `gcloud beta terraform vet` produces the same asset format from your plan,
> so one policy can check both planned and existing resources.

### Installing

`terraform vet` is part of the `terraform-tools` component of the Google
Cloud CLI:

```console
$ gcloud components install terraform-tools
```

On Debian/Ubuntu systems where `gcloud` was installed with `apt`, use
`sudo apt-get install google-cloud-cli-terraform-tools` instead. `gcloud`
also offers to install it the first time you run `gcloud beta terraform vet`.

### Exit codes

| Exit code | Meaning |
|---|---|
| `0` | No violations. |
| `2` | Violations found. |
| `1` | Error (e.g. invalid policy library, missing credentials). |

This makes it easy to **fail a pipeline** when violations are found
(Chapters 21 and 22).

### Permissions

Because of the CAI conversion step, `vet` needs credentials that can **read**
the project: its ancestry and the current IAM policies of resources the plan
touches. Locally your ADC/gcloud login is used. In CI, give the pipeline's
service account read roles such as `roles/viewer` and
`roles/iam.securityReviewer`.

## 20.3 The policy library

```
policy-library/
├── lib/                          # shared Rego helper functions (may be empty, must exist)
└── policies/
    ├── templates/                # ConstraintTemplates: HOW to check (Rego)
    │   ├── tf-storage-bucket-location-allowlist-v1.yaml
    │   ├── tf-storage-bucket-public-access-prevention-v1.yaml
    │   ├── tf-required-labels-v1.yaml
    │   └── gcp-iam-banned-members-v1.yaml
    └── constraints/              # Constraints: WHAT to enforce, with parameters
        ├── storage_location_europe.yaml
        ├── storage_public_access_prevention.yaml
        ├── required_labels.yaml
        └── no_public_cloud_run.yaml
```

* A **constraint template** defines a reusable rule and its parameters,
  e.g. "bucket location must be in an allow-list".
* A **constraint** *activates* a template with concrete parameters and scope,
  e.g. "allowed locations are EU, EUROPE-WEST1, … for all resources".

Only templates that have at least one constraint are enforced. The same
template can be used by several constraints with different parameters (for
example a stricter list for prod).

> **Note:** Google used to maintain a large public policy library
> (`GoogleCloudPlatform/policy-library`) with dozens of ready-made templates.
> It was archived in August 2025. It remains a useful source of examples (pin a commit
> if you copy from it), but this chapter teaches you to write and own your
> templates, which is what most teams end up doing.

## 20.4 Terraform-based constraints

Terraform-based constraints look at a single **resource change** from the
plan JSON — exactly what you saw in `terraform show -json`:

```json
{
  "address": "google_storage_bucket.scratch",
  "type": "google_storage_bucket",
  "name": "scratch",
  "change": {
    "actions": ["create"],
    "before": null,
    "after": {
      "location": "EUROPE-WEST1",
      "name": "tf-book-fatih-12345-ch20-scratch",
      "uniform_bucket_level_access": true,
      ...
    }
  }
}
```

They're simple to write because you use Terraform resource types and
argument names you already know.

### A template

`policies/templates/tf-storage-bucket-location-allowlist-v1.yaml`:

```yaml
apiVersion: templates.gatekeeper.sh/v1beta1
kind: ConstraintTemplate
metadata:
  name: tfstoragebucketlocationallowlistconstraintv1   # lowercase kind
spec:
  crd:
    spec:
      names:
        kind: TFStorageBucketLocationAllowlistConstraintV1
      validation:
        openAPIV3Schema:                                 # parameters accepted
          properties:
            allowed_locations:
              description: Bucket locations that are allowed, in upper case.
              type: array
              items:
                type: string
  targets:
    - target: validation.resourcechange.terraform.cloud.google.com
      rego: |
        package templates.gcp.TFStorageBucketLocationAllowlistConstraintV1

        violation[{
          "msg": message,
          "details": metadata,
        }] {
          resource := input.review
          resource.type == "google_storage_bucket"
          location := upper(resource.change.after.location)
          allowed := {upper(l) | l := input.parameters.allowed_locations[_]}
          not allowed[location]

          message := sprintf("%s: location %s is not allowed. Allowed: %v", [resource.address, location, input.parameters.allowed_locations])
          metadata := {"resource": resource.address, "location": location}
        }
```

The important parts:

* `target: validation.resourcechange.terraform.cloud.google.com` marks it as a
  **Terraform-based** template.
* The Rego `package` must be `templates.gcp.<Kind>`.
* The rule must be called **`violation`** and produce objects with `msg` and
  `details`.
* `input.review` is the resource change; `input.parameters` holds the
  constraint's parameters.
* Every line in the rule body must be true for a violation to be reported.
  Think of it as: "it's a violation **if** the type is a bucket **and** its
  location is **not** in the allowed set".

#### Rego in five minutes

| Rego | Meaning |
|---|---|
| `x := expr` | Assign a local variable. |
| `a == b` | Must be equal (otherwise this rule body doesn't match). |
| `list[_]` | "Some element of list" — iterates. |
| `not expr` | True if `expr` is false or undefined. |
| `{f(x) \| x := list[_]}` | Set comprehension. |
| `set[value]` | True if `value` is in the set. |
| `sprintf(fmt, [args])` | Format a string. |
| `upper`, `lower`, `startswith`, `contains`, `count`, `is_object` | Built-in functions. |
| `f(x) = y { ... } else = z` | Helper function with a default. |

If an attribute doesn't exist (e.g. `after` is `null` for a delete), the
expression is *undefined* and the rule simply doesn't match — so deletions
don't cause violations.

### A constraint

`policies/constraints/storage_location_europe.yaml`:

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: TFStorageBucketLocationAllowlistConstraintV1   # matches the template kind
metadata:
  name: storage-location-europe                      # lowercase, hyphens only
spec:
  severity: high
  match:
    addresses:                                       # Terraform addresses (globs)
      - "**"
  parameters:
    allowed_locations:
      - EU
      - EUROPE-WEST1
      - EUROPE-WEST3
      - EUROPE-WEST4
```

* `match.addresses` selects resources by Terraform address with glob
  patterns (`"**"` = everything, `"module.web_app.**"` = one module).
  `excludedAddresses` lists exceptions.
* `metadata.name` must be a valid Kubernetes name: lowercase letters, digits,
  and hyphens.

### A rule with a helper function

Required labels, for several resource types:

```rego
package templates.gcp.TFRequiredLabelsConstraintV1

violation[{
  "msg": message,
  "details": metadata,
}] {
  resource := input.review
  resource.type == input.parameters.resource_types[_]
  is_object(resource.change.after)                 # skip deletes
  labels := get_labels(resource.change.after)
  required := input.parameters.required_labels[_]
  not labels[required]

  message := sprintf("%s: missing required label %q", [resource.address, required])
  metadata := {"resource": resource.address, "missing_label": required}
}

get_labels(after) = labels {
  labels := after.labels
  is_object(labels)
} else = {}
```

```yaml
kind: TFRequiredLabelsConstraintV1
metadata:
  name: required-labels
spec:
  severity: medium
  match:
    addresses: ["**"]
  parameters:
    resource_types: [google_storage_bucket, google_cloud_run_v2_service]
    required_labels: [environment, managed_by]
```

> **Tip:** The Google provider's `default_labels` (Chapter 4) are merged into
> `terraform_labels`, not `labels`, in the plan. If you rely on
> `default_labels`, check `terraform_labels` in your policy instead.

## 20.5 CAI-based constraints

CAI-based constraints evaluate the **Cloud Asset Inventory** representation.
They shine when the rule depends on information that isn't in the plan alone:

* **IAM policies** — the *combined* effect of all bindings on a resource,
  including bindings that already exist.
* **Ancestry** — the folder or organisation a project belongs to, so you can
  scope rules: "in the `prod` folder, …".
* Rules that should work identically for Terraform and for other tools that
  produce CAI data (e.g. continuous scanning of real assets).

A CAI asset looks like this:

```json
{
  "name": "//run.googleapis.com/projects/my-proj/locations/europe-west1/services/ch20-hello",
  "asset_type": "run.googleapis.com/Service",
  "ancestry_path": "organizations/123/folders/456/projects/789",
  "iam_policy": {
    "bindings": [{ "role": "roles/run.invoker", "members": ["allUsers"] }]
  },
  "resource": { "data": { ... } }
}
```

Template (`gcp-iam-banned-members-v1.yaml`, Rego part):

```rego
package templates.gcp.GCPIAMBannedMembersConstraintV1

violation[{
  "msg": message,
  "details": metadata,
}] {
  asset := input.review
  asset.asset_type == input.parameters.asset_types[_]
  binding := asset.iam_policy.bindings[_]
  member := binding.members[_]
  member == input.parameters.banned_members[_]

  message := sprintf("%s grants %s to %s, which is not allowed", [asset.name, binding.role, member])
  metadata := {"resource": asset.name, "role": binding.role, "member": member}
}
```

with `target: validation.gcp.forsetisecurity.org` in the template. The
constraint scopes by **ancestry** instead of Terraform address:

```yaml
apiVersion: constraints.gatekeeper.sh/v1beta1
kind: GCPIAMBannedMembersConstraintV1
metadata:
  name: no-public-cloud-run
spec:
  severity: high
  match:
    ancestries:
      - "**"                       # or e.g. "organizations/123/folders/456/**"
  parameters:
    asset_types:
      - run.googleapis.com/Service
    banned_members:
      - allUsers
      - allAuthenticatedUsers
```

### Which type should I use?

| | Terraform-based | CAI-based |
|---|---|---|
| Input | Plan resource change | Cloud Asset Inventory asset |
| Field names | Terraform arguments (`public_access_prevention`) | Google API fields (`iamConfiguration.publicAccessPrevention`) |
| Scope by | Terraform address | Organisation/folder/project ancestry |
| Sees existing IAM bindings | No | Yes |
| Easiest to write | ✓ | |
| Works beyond Terraform | | ✓ |

Start with Terraform-based constraints; use CAI-based ones for IAM and
hierarchy-aware rules.

## 20.6 Reading the output

```console
$ gcloud beta terraform vet tfplan.json --policy-library=./policy-library --format=json
[
  {
    "constraint": "TFStorageBucketPublicAccessPreventionConstraintV1.storage-public-access-prevention",
    "constraint_config": { ... },
    "message": "google_storage_bucket.scratch: public_access_prevention must be set to \"enforced\"",
    "metadata": { "details": { "resource": "google_storage_bucket.scratch" } },
    "resource": "google_storage_bucket.scratch",
    "severity": "high"
  },
  ...
]
$ echo $?
2
```

Each violation names the **constraint**, the **resource**, a human-readable
**message**, and the **severity**. In a pipeline you can post these messages
as a pull request comment.

## 20.7 Testing your policies

Policies are code too, so test them:

* Keep a small **sample configuration** with one compliant and one
  non-compliant resource for each rule, and check that `vet` reports exactly
  the expected violations (this chapter's exercise does that).
* The Terraform-based checks can also run **offline**, without credentials,
  by calling the underlying binary directly:

  ```console
  $ "$(dirname "$(command -v gcloud)")/terraform-tools" validate-tfplan tfplan.json --policy-library=./policy-library
  ```

  (`validate-tfplan` only evaluates Terraform-based constraints; CAI-based ones
  need the full `gcloud beta terraform vet` with credentials.)
* For larger libraries, write Rego unit tests with `opa test`.

## 20.8 Comparing policy tools

| Tool | Runs where | Language | Strengths |
|---|---|---|---|
| **`gcloud terraform vet`** | Anywhere (laptop, any CI) | Rego (Constraint Framework) | Google-native, CAI + ancestry, same constraints as Google's Config Validator ecosystem |
| **Sentinel** (Chapter 17) | HCP Terraform / Enterprise | Sentinel | Deep Terraform integration (plan, config, state, cost), enforcement levels with overrides |
| **OPA** in HCP Terraform (Chapter 17) | HCP Terraform / Enterprise | Rego | Open standard |
| **Terraform Policy** (`terraform plan -policies`) | Terraform CLI 1.17+ | HCL-based policies | Built into the CLI (newer than the exam) |
| **Checkov, Trivy, tfsec** | Anywhere | Built-in rules (+ custom) | Hundreds of ready-made security rules, scan code without a plan |
| **Organization Policy Service** | Google Cloud itself | Built-in + custom constraints | Enforced by Google at API level — even for console clicks |

These tools complement each other. A common combination: **Organization
Policies** as the hard guardrail in Google Cloud (e.g. "resource locations:
EU only"), **Checkov/Trivy** for broad security scanning, and **`terraform
vet`** (or Sentinel/OPA) for company-specific rules with early, readable
feedback in pull requests.

## Common mistakes and tips

* Forgetting the `lib/` directory — the policy library fails to load.
* Using underscores in constraint `metadata.name` — must be lowercase with
  hyphens.
* Leaving out `spec.crd.spec.validation.openAPIV3Schema` in a template —
  include it (an empty `properties: {}` is fine) or the tool may crash.
* A template without any constraint does nothing.
* Treating `vet` exit code 2 as an "error" in scripts — it means "violations",
  which is exactly what you want to fail the pipeline on.
* Writing a condition that matches compliant resources — a `violation` rule
  must match only **bad** resources.

## Summary

* Policy as code turns organisational rules into automated checks on every
  plan.
* `gcloud beta terraform vet` validates a plan JSON against a policy library
  and returns `0`, `2` (violations), or `1` (error).
* A policy library contains templates (Rego rules) and constraints
  (parameters and scope) plus a `lib/` folder.
* Terraform-based constraints use plan resource changes and Terraform field
  names; CAI-based constraints use Cloud Asset Inventory data, IAM policies,
  and ancestry.
* Combine `vet` with Organization Policies and scanners for defence in depth.

## Quick check

1. Why do policy tools check the plan rather than the `.tf` files?
2. What's the difference between a constraint template and a constraint?
3. What does exit code `2` from `gcloud beta terraform vet` mean?
4. Which kind of constraint would you use to ban `allUsers` from IAM policies,
   including bindings that already exist, and why?
5. What must the Rego rule in a template be called, and what must it return?

---

## Hands-on exercise: Enforce your company's rules

**Goal:** Run `gcloud beta terraform vet` against a sample configuration,
complete a Terraform-based template, add a CAI-based constraint, and see a
pipeline-style pass/fail.

**Estimated time:** 30 minutes

**Files:** `code/ch20-policy-as-code/exercise/`

### Steps

1. **Install the component** (if not done):
   `gcloud components install terraform-tools`.
2. `cd code/ch20-policy-as-code/exercise/sample`, create `terraform.tfvars`,
   and `terraform init`. Then go back one folder (`cd ..`).
3. **First run.** Read `vet.sh`, then run it:

   ```console
   $ ./vet.sh sample policy-library
   ```

   You should see one violation: the `scratch` bucket doesn't enforce public
   access prevention. Note the exit code (`echo $?` → 2).
4. **Complete the labels template.** Open
   `policy-library/policies/templates/tf-required-labels-v1.yaml` and replace
   the placeholder `violation` rule following the `TODO`s. Run `./vet.sh`
   again — now the `scratch` bucket also reports two missing labels.
5. **Trigger the location rule.** Run
   `./vet.sh sample policy-library -var bucket_location=US`. A third kind of
   violation appears for the `reports` bucket.
6. **Add a CAI constraint.** Turn
   `policy-library/policies/constraints/no_public_cloud_run.yaml.todo` into a
   real constraint (`no_public_cloud_run.yaml`) that bans `allUsers` and
   `allAuthenticatedUsers` on Cloud Run services. Run
   `./vet.sh sample policy-library -var public_service=true` and find the IAM
   violation.
7. **Fix the code.** In `sample/main.tf`, make the `scratch` bucket compliant
   (public access prevention + labels). Run `./vet.sh` (default variables):
   exit code `0`, "No policy violations."
8. **Scope a rule.** Change `required_labels.yaml` so it ignores the address
   `google_storage_bucket.scratch` using `excludedAddresses` (a list under
   `match`, next to `addresses`). Revert `scratch` to its original,
   non-compliant form (remove both the labels and `public_access_prevention`)
   and confirm that only the public-access rule fires for it.

### Expected result

A policy library with four active constraints, a non-zero exit code when the
sample violates them, and exit code `0` once the configuration is compliant.

### Stretch goal

Write a new Terraform-based template
`TFComputeInstanceAllowedMachineTypesConstraintV1` that only allows
`e2-micro` and `e2-small` for `google_compute_instance`, add a constraint, and
test it with a sample VM.

### Challenge

*Optional, about 35 minutes. There are no starter files and no `TODO`s: work
in a new, empty folder from the requirements alone. A reference solution is in
`code/ch20-policy-as-code/challenge/`.*

Your company wants a cost guardrail: **no Cloud Run service may scale beyond
10 instances.** Write the policy.

* A new Terraform-based constraint template with a parameter for the limit,
  and a constraint that sets it to 10 for all addresses.
* Look at `terraform show -json tfplan` for the sample's Cloud Run service
  to find where the instance limit sits in a resource change.
* A service that sets **no** limit must be reported too. Google's default is
  far higher than 10.
* Deleting a service must not be reported.

Test it with three versions of the sample's service: a limit of 3, a limit
of 50, and no `scaling` block at all.

**Done when** `./vet.sh` reports nothing for the first version and one
violation with a clear message for each of the other two. How would you
give one module a stricter limit without writing a second template?

### Cleanup

Nothing was applied — `vet.sh` only plans. Delete any leftover `tfplan` and
`tfplan.json` files.

---

## Quick check answers

1. The plan contains the final, fully resolved values of every resource to
   be created or changed — after variables, modules, functions, and defaults
   are applied.
2. A template defines a reusable rule (Rego) and the parameters it accepts; a
   constraint activates a template with concrete parameters and a scope.
3. Violations were found.
4. A CAI-based constraint, because CAI conversion includes the resource's
   full IAM policy (existing bindings merged with planned changes) and its
   ancestry.
5. `violation`; it must produce objects with `msg` and `details` keys.
