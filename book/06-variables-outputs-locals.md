# Chapter 6 — Variables, Outputs, and Locals

## Learning objectives

By the end of this lesson you will be able to:

* Declare **input variables** with types, defaults, and descriptions, and set
  them in several ways. `[4c]`
* Explain **variable definition precedence**. `[4c]`
* Declare **outputs** and read them with `terraform output`. `[4c]`
* Use **locals** to name and reuse expressions.
* Use the primitive and **complex types**: `list`, `set`, `map`, `object`,
  `tuple`, and `optional()` attributes. `[4d]`

---

## 6.1 Why variables?

In Chapter 5, the project ID, region, and resource names were hard-coded.
To deploy the same thing to a second project or region, you'd have to edit
the code. **Input variables** turn values into parameters — like function
arguments for your configuration.

```
  inputs (variables) ──▶  configuration  ──▶  outputs
                           (resources,
                            locals)
```

## 6.2 Declaring input variables `[4c]`

```hcl
variable "project_id" {
  description = "The Google Cloud project to deploy into."
  type        = string
}

variable "region" {
  description = "Region for regional resources."
  type        = string
  default     = "europe-west1"
}
```

The `variable` block's label (`project_id`) is the variable's name. All
arguments are optional, but good practice is to always set `description` and
`type`.

| Argument | Purpose |
|---|---|
| `type` | Allowed type of value (see 6.6). Terraform converts or rejects values. |
| `default` | Value used if none is provided. Without a default, the variable is **required**. |
| `description` | Documentation for users of your code. |
| `sensitive` | Hide the value in plan/apply output (Chapter 14). |
| `nullable` | Whether `null` is an acceptable value (default `true`). |
| `validation` | Custom rules for allowed values (Chapter 8). |
| `ephemeral` | Value is never stored in state or plan (Chapter 14). |

Use variables with the `var.` prefix:

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}
```

By convention, variables live in `variables.tf`.

## 6.3 Setting variable values

There are many ways to provide values. If a required variable has no value,
Terraform asks interactively:

```console
$ terraform plan
var.project_id
  The Google Cloud project to deploy into.

  Enter a value:
```

That's fine for experiments but not for real work. Better options:

**1. A `terraform.tfvars` file** (loaded automatically)

```hcl
# terraform.tfvars
project_id = "tf-book-fatih-12345"
region     = "europe-west1"
```

**2. Any `*.auto.tfvars` file** (also loaded automatically, in alphabetical
order)

**3. A named file with `-var-file`**

```console
$ terraform plan -var-file=prod.tfvars
```

**4. Individual `-var` flags**

```console
$ terraform plan -var="region=us-central1"
```

**5. Environment variables named `TF_VAR_<name>`**

```console
$ export TF_VAR_project_id=tf-book-fatih-12345
$ terraform plan
```

JSON versions also work: `terraform.tfvars.json`, `*.auto.tfvars.json`.

### Precedence `[4c]`

If the same variable is set in several places, the **later** source in this
list wins:

1. Default value in the `variable` block (lowest)
2. Environment variables `TF_VAR_name`
3. `terraform.tfvars`
4. `terraform.tfvars.json`
5. `*.auto.tfvars` / `*.auto.tfvars.json` (alphabetical order)
6. `-var` and `-var-file` on the command line, **in the order given**
   (highest)

> **Exam tip:** Memorise this order. Command-line flags beat files, files beat
> environment variables, and everything beats the default.

> **Security tip:** `terraform.tfvars` often contains environment-specific
> or secret values. Many teams commit a `terraform.tfvars.example` and add
> `terraform.tfvars` to `.gitignore` — this book's code does exactly that.

## 6.4 Outputs `[4c]`

Outputs expose values from your configuration:

```hcl
output "bucket_url" {
  description = "gs:// URL of the bucket."
  value       = google_storage_bucket.data.url
}
```

They are used to:

* **Show useful information** after `apply` (an IP address, a URL).
* **Pass values from a child module** to its parent (Chapter 13).
* **Share values between configurations** via remote state (Chapter 10).
* **Feed scripts and pipelines** via `terraform output -json`.

```console
$ terraform apply
...
Outputs:

bucket_url = "gs://tf-book-fatih-12345-data"

$ terraform output
bucket_url = "gs://tf-book-fatih-12345-data"

$ terraform output bucket_url
"gs://tf-book-fatih-12345-data"

$ terraform output -raw bucket_url        # no quotes, ideal for scripts
gs://tf-book-fatih-12345-data

$ terraform output -json
{
  "bucket_url": {
    "sensitive": false,
    "type": "string",
    "value": "gs://tf-book-fatih-12345-data"
  }
}
```

Output arguments:

| Argument | Purpose |
|---|---|
| `value` | Required. Any expression. |
| `description` | Documentation. |
| `sensitive` | Hide the value in CLI output (it's still stored in state!). |
| `depends_on` | Rarely needed explicit dependency. |
| `precondition` | Check a condition before outputting (Chapter 8). |

Outputs are stored in the state file. `terraform output` reads them from
state; it doesn't contact the cloud.

## 6.5 Locals

A **local value** gives a name to an expression so you can reuse it. Think of
it as a variable *inside* your configuration that users can't set.

```hcl
locals {
  name_prefix = "${var.environment}-web"

  common_labels = {
    environment = var.environment
    managed_by  = "terraform"
    team        = var.team
  }
}

resource "google_storage_bucket" "data" {
  name     = "${var.project_id}-${local.name_prefix}-data"
  location = var.region
  labels   = local.common_labels
}
```

Note the different keywords: the block is `locals` (plural); references use
`local.` (singular).

When to use what:

| | Set by the user? | Use for |
|---|---|---|
| `variable` | Yes | Things that differ between deployments |
| `local` | No | Derived values, repeated expressions, naming conventions |
| `output` | — | Values you want to expose |

Don't overuse locals: a local that just copies a variable adds indirection
without value.

## 6.6 Types `[4d]`

### Primitive types

| Type | Example |
|---|---|
| `string` | `"europe-west1"` |
| `number` | `3`, `0.5` |
| `bool` | `true`, `false` |

Terraform converts between primitives automatically where it can
(`"3"` → `3`, `"true"` → `true`).

### Collection types (all elements share one type)

| Type | Example | Notes |
|---|---|---|
| `list(string)` | `["a", "b", "a"]` | Ordered, duplicates allowed, index with `[0]`. |
| `set(string)` | `toset(["a", "b"])` | Unordered, unique values, no indexing. |
| `map(string)` | `{ team = "web", env = "dev" }` | Keys are strings; access with `["team"]` or `.team`. |

### Structural types (elements can have different types)

**`object`** — named attributes with their own types:

```hcl
variable "bucket" {
  type = object({
    name           = string
    location       = string
    versioning     = bool
    retention_days = number
  })
}
```

```hcl
# terraform.tfvars
bucket = {
  name           = "reports"
  location       = "EU"
  versioning     = true
  retention_days = 30
}
```

**`tuple`** — a fixed-length sequence where each position has its own type:

```hcl
variable "port_and_protocol" {
  type    = tuple([number, string])
  default = [443, "tcp"]
}
```

Tuples are rare in variables; you meet them mostly as results of
expressions like `[1, "a"]`.

### Optional object attributes

`optional(type, default)` makes an object attribute optional, with an
optional default:

```hcl
variable "buckets" {
  description = "Buckets to create, keyed by short name."
  type = map(object({
    location      = string
    storage_class = optional(string, "STANDARD")
    versioning    = optional(bool, false)
  }))
}
```

```hcl
buckets = {
  logs    = { location = "EU" }
  backups = { location = "EU", storage_class = "NEARLINE", versioning = true }
}
```

`logs` gets `storage_class = "STANDARD"` and `versioning = false` from the
defaults.

### `any`

`type = any` accepts anything and lets Terraform infer the type. It's
convenient but loses validation. Prefer precise types.

### Accessing complex values

```hcl
var.zones[0]                     # list element
var.labels["team"]               # map element
var.labels.team                  # same, attribute syntax
var.bucket.location              # object attribute
var.buckets["backups"].versioning
```

> **Exam tip:** Know the difference between collection types (`list`, `map`,
> `set` — one element type) and structural types (`object`, `tuple` — mixed
> types). Sets are unordered and contain unique values.

## 6.7 A complete, parameterised configuration

**`variables.tf`**

```hcl
variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "Default region."
  type        = string
  default     = "europe-west1"
}

variable "environment" {
  description = "Deployment environment name, e.g. dev or prod."
  type        = string
  default     = "dev"
}

variable "labels" {
  description = "Extra labels applied to all resources."
  type        = map(string)
  default     = {}
}

variable "buckets" {
  description = "Buckets to create, keyed by short name."
  type = map(object({
    location      = string
    storage_class = optional(string, "STANDARD")
    versioning    = optional(bool, false)
  }))
}
```

**`main.tf`**

```hcl
locals {
  common_labels = merge(var.labels, {
    environment = var.environment
    managed_by  = "terraform"
  })
}

resource "google_storage_bucket" "logs" {
  name                        = "${var.project_id}-${var.environment}-logs"
  location                    = var.buckets["logs"].location
  storage_class               = var.buckets["logs"].storage_class
  uniform_bucket_level_access = true
  force_destroy               = true
  labels                      = local.common_labels

  versioning {
    enabled = var.buckets["logs"].versioning
  }
}
```

`merge()` combines maps (Chapter 7 covers functions). In Chapter 7 you'll
learn `for_each` to create *one bucket per map entry* without repeating the
resource block.

## Common mistakes and exam tips

* Using `var.` for locals or `local.` for variables. Also: `locals` block,
  `local.` reference.
* Expecting `terraform.tfvars` in a sub-folder to be loaded — only the
  working directory's files are loaded automatically. Other names need
  `-var-file`.
* `sensitive = true` hides values from CLI output, **not from the state
  file**.
* A variable without `default` is required.
* `-var` flags override everything else.
* Variables can't reference other variables in their `default`; use locals
  for derived values.

## Summary

* Variables parameterise configuration; set them with tfvars files, `-var`,
  `-var-file`, or `TF_VAR_` environment variables, following a strict
  precedence order.
* Outputs expose values for humans, parent modules, other configurations, and
  scripts.
* Locals name intermediate expressions.
* Types: `string`, `number`, `bool`; collections `list`, `set`, `map`;
  structural `object`, `tuple`; `optional()` for object attributes.

## Quick check

1. A variable has `default = "dev"`, `TF_VAR_environment=test` is set,
   `terraform.tfvars` contains `environment = "staging"`, and you run
   `terraform plan -var environment=prod`. Which value is used?
2. What is the difference between a `list` and a `set`?
3. How do you print only the raw value of an output named `ip` for use in a
   shell script?
4. Does `sensitive = true` keep a value out of the state file?
5. Write a variable type for a map of objects where each object has a
   required `cidr` string and an optional `private` bool defaulting to `true`.

---

## Hands-on exercise: Parameterise a configuration

**Goal:** Turn a hard-coded configuration into a reusable one with variables,
locals, outputs, and complex types.

**Estimated time:** 25 minutes

**Files:** `code/ch06-variables/exercise/`

### Steps

1. `cd code/ch06-variables/exercise`. Copy `terraform.tfvars.example` to
   `terraform.tfvars` and set your project ID.
2. In `variables.tf`, complete the `TODO`s: declare `region` (default
   `europe-west1`), `environment` (default `dev`), `labels` (map of strings,
   default `{}`), and `network` — an object with `name` (string) and
   `subnet_cidr` (string), plus an optional `allowed_ports` list of strings
   defaulting to `["80"]`.
3. In `main.tf` and `providers.tf`, replace every hard-coded value marked
   `TODO` with a variable or local. Create a local `common_labels` that merges `var.labels` with
   `environment` and `managed_by`.
4. In `outputs.tf`, output the bucket URL, the network ID, and the subnet's
   CIDR range.
5. Run `terraform init`, `plan`, and `apply`. Then try:

   ```console
   $ terraform output
   $ terraform output -raw bucket_url
   $ terraform output -json | jq
   ```

6. **Precedence experiment:** Without applying, run
   `TF_VAR_environment=test terraform plan`. The plan says "No changes",
   because your `terraform.tfvars` sets `environment = "dev"`, and a tfvars
   file beats an environment variable. Then also add
   `-var environment=prod`. Which wins now? (Look at the bucket name in the
   plan: renaming forces replacement.) Now create
   `override.auto.tfvars` with `environment = "auto"` and run plain
   `terraform plan`. Delete the file afterwards.
7. Open `terraform console` and evaluate `var.network`, `local.common_labels`,
   and `var.network.allowed_ports[0]`. Exit with `exit` or Ctrl+D.

### Expected result

Resources named after your environment, labelled with `environment`,
`managed_by`, and your extra labels, and three outputs.

### Stretch goal

Create `prod.tfvars` with different values and run
`terraform plan -var-file=prod.tfvars`. What would change?

### Cleanup

```console
$ terraform destroy
```

---

## Quick check answers

1. `prod` — `-var` on the command line has the highest precedence.
2. A list is ordered and may contain duplicates; a set is unordered, contains
   unique values, and cannot be indexed.
3. `terraform output -raw ip`.
4. No. It only hides the value in CLI output; the value is stored in state in
   plain text.
5. `map(object({ cidr = string, private = optional(bool, true) }))`
