# Chapter 8 — Custom Conditions and Lifecycle Rules

## Learning objectives

By the end of this lesson you will be able to:

* Validate input variables with `validation` blocks. `[4g]`
* Guard resources and outputs with `precondition` and `postcondition`. `[4g]`
* Continuously verify infrastructure with `check` blocks. `[4g]`
* Explain when each kind of condition is evaluated and what happens when it
  fails. `[4g]`
* Control resource behaviour with the `lifecycle` meta-argument:
  `create_before_destroy`, `prevent_destroy`, `ignore_changes`, and
  `replace_triggered_by`.

**Time:** about 50 minutes — 20 reading, 5 quick check, 25 exercise.

---

## 8.1 Why custom conditions?

Types catch some mistakes: a `number` variable rejects `"abc"`. But many
rules are about *meaning*, not type:

* `environment` must be `dev`, `staging`, or `prod`.
* Bucket names must be lowercase and at most 63 characters.
* The VM image we looked up must be in the `READY` state, not deprecated or pending.
* After creation, the bucket must have uniform bucket-level access enabled.

Custom conditions let you encode these rules so mistakes are caught **early**
with **clear error messages**, rather than as cryptic API errors halfway
through an apply.

Terraform offers four mechanisms:

| Mechanism | Where | When evaluated | On failure |
|---|---|---|---|
| `validation` | inside `variable` | Before planning, when the value is known | **Error**, stops |
| `precondition` | inside a resource/data `lifecycle`, or an `output` | Before the object is planned/applied | **Error**, stops |
| `postcondition` | inside a resource/data `lifecycle` | After the object is planned/applied | **Error**, stops |
| `check` block | top level | At the end of every plan and apply | **Warning**, continues |

All of them share the same shape:

```hcl
condition     = <expression that returns true when everything is OK>
error_message = "A clear sentence explaining what is wrong."
```

## 8.2 Input variable validation `[4g]`

```hcl
variable "environment" {
  description = "Deployment environment."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}
```

```console
$ terraform plan -var environment=qa
╷
│ Error: Invalid value for variable
│
│   on variables.tf line 1:
│    1: variable "environment" {
│     ├────────────────
│     │ var.environment is "qa"
│
│ environment must be one of: dev, staging, prod.
│
│ This was checked by the validation rule at variables.tf:5,3-13.
╵
```

You can have several `validation` blocks per variable. Common patterns:

```hcl
variable "bucket_suffix" {
  type = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.bucket_suffix))
    error_message = "bucket_suffix may only contain lowercase letters, digits, and hyphens."
  }

  validation {
    condition     = length(var.bucket_suffix) <= 30
    error_message = "bucket_suffix must be 30 characters or fewer."
  }
}

variable "instance_count" {
  type = number

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 5
    error_message = "instance_count must be between 1 and 5."
  }
}

variable "subnet_cidr" {
  type = string

  validation {
    condition     = can(cidrhost(var.subnet_cidr, 0))
    error_message = "subnet_cidr must be a valid CIDR block, e.g. 10.0.0.0/24."
  }
}
```

`can()` turns an error into `false`, which makes it perfect for validations:
"can this be parsed as a regex match / CIDR / number?"

Since Terraform 1.9, a validation may also refer to **other variables, locals,
and data sources**, not just the variable being validated:

```hcl
variable "max_nodes" {
  type = number

  validation {
    condition     = var.max_nodes >= var.min_nodes
    error_message = "max_nodes must be greater than or equal to min_nodes."
  }
}
```

## 8.3 Preconditions and postconditions `[4g]`

Preconditions and postconditions live in a resource's or data source's
`lifecycle` block.

* A **precondition** checks assumptions **before** Terraform plans or applies
  the object. Use it to check inputs and other objects that this object
  relies on.
* A **postcondition** checks guarantees **after** the object is planned or
  applied, using `self` to refer to the object's own attributes.

```hcl
data "google_compute_image" "app" {
  family  = var.image_family
  project = var.image_project

  lifecycle {
    postcondition {
      condition     = self.status == "READY"
      error_message = "The image ${self.name} is not READY and cannot be used for new VMs."
    }
  }
}

resource "google_compute_instance" "app" {
  name         = "app"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.app.self_link
    }
  }

  shielded_instance_config {
    enable_secure_boot = true
  }

  network_interface {
    network = "default"
  }

  lifecycle {
    precondition {
      condition     = var.environment != "prod" || !startswith(var.machine_type, "e2-micro")
      error_message = "e2-micro is too small for production."
    }
  }
}
```

Postconditions are great on **data sources**: they verify that the object you
looked up is what you expected, before anything is built on top of it.

### Preconditions on outputs

An output can have a precondition too — useful in modules to guarantee
something about a value you return:

```hcl
output "web_url" {
  value = google_cloud_run_v2_service.web.uri # already starts with https://

  precondition {
    condition     = google_cloud_run_v2_service.web.ingress == "INGRESS_TRAFFIC_ALL"
    error_message = "The service is not publicly reachable."
  }
}
```

> [!NOTE]
> **Google Cloud: Cloud Run.** **Cloud Run** runs containers without servers
> for you to manage. You give it a container image, and it gives you an HTTPS
> URL ending in `.run.app` (the `uri` attribute). It starts container
> instances when requests arrive and scales down to zero when there are none,
> so an idle service costs nothing. Every deployment creates an immutable
> **revision**, and the **service** sends traffic to its revisions. Two
> settings decide who can reach a service: **ingress** says where requests may
> come from (`INGRESS_TRAFFIC_ALL` means the internet), and IAM says who may
> call it (`roles/run.invoker`; granting it to `allUsers` makes the service
> public). Services are regional. Chapter 14 deploys one.

### Which one should I use?

* Rule about a single **input value** → `validation`.
* Assumption about **other things** this resource relies on (combinations of
  variables, data source results) → `precondition`.
* Guarantee about **this object's result** that others will rely on →
  `postcondition`.

If a condition depends on values only known after apply, Terraform evaluates
it during the apply instead of the plan.

## 8.4 `check` blocks: continuous validation `[4g]`

Conditions above **stop** Terraform when they fail. A `check` block instead
reports a **warning** and lets the plan or apply continue. It's for verifying
the *overall health* of your infrastructure, on every run.

```hcl
check "website_is_up" {
  data "http" "home" {
    url = "http://${google_compute_instance.web.network_interface[0].access_config[0].nat_ip}"
  }

  assert {
    condition     = data.http.home.status_code == 200
    error_message = "The website returned HTTP ${data.http.home.status_code}."
  }
}
```

* A check block contains one or more `assert` blocks.
* It may contain one **scoped data source** (`data "http" "home"` above) that
  is only visible inside the check. If reading that data source fails, the
  failure is also reported as a warning.
* Checks run at the end of every `plan` and `apply`.
* In HCP Terraform, **health assessments** run checks on a schedule
  (Chapter 17).

```console
│ Warning: Check block assertion failed
│
│   on main.tf line 60, in check "website_is_up":
│   60:     condition     = data.http.home.status_code == 200
│
│ The website returned HTTP 502.
```

> **Exam tip:** Remember: `validation`, `precondition`, and `postcondition`
> **block** operations with an error; `check` blocks produce **warnings** and
> never block.

## 8.5 The `lifecycle` meta-argument

The same `lifecycle` block that holds pre/postconditions also customises how
Terraform creates, updates, and destroys a resource.

### `create_before_destroy`

When a change forces replacement, Terraform by default **destroys the old
object first**, then creates the new one (`-/+`). That means downtime, and it
fails if the new object needs the old one's name. With
`create_before_destroy = true`, Terraform creates the replacement first and
then destroys the old one (`+/-`):

```hcl
resource "google_compute_instance_template" "web" {
  name_prefix  = "web-"
  machine_type = "e2-micro"
  # ...

  lifecycle {
    create_before_destroy = true
  }
}
```

Note `name_prefix`: since both objects exist briefly, they need different
names. Google generates a unique suffix.

> [!NOTE]
> **Google Cloud: instance templates.** An **instance template** is a
> blueprint for VMs: machine type, image, network, metadata. A **managed
> instance group** uses it to create and replace identical VMs, for example to
> scale out or to heal a broken one. Templates can't be changed after
> creation, so every change to a template means a new one, and the group must
> be pointed at it before the old one can be deleted. That's exactly the order
> `create_before_destroy` gives you.

### `prevent_destroy`

Protects critical resources from accidental deletion:

```hcl
resource "google_storage_bucket" "terraform_state" {
  name     = "acme-terraform-state"
  location = "EU"

  lifecycle {
    prevent_destroy = true
  }
}
```

Any plan that would destroy this resource **fails with an error**. To really
delete it, you must first remove `prevent_destroy` from the code. Caveat: if
you delete the *whole resource block* from the configuration,
`prevent_destroy` goes with it and no longer protects the object.

Many Google resources also have their own server-side protection, for
example `deletion_protection = true` on `google_compute_instance` and Cloud
SQL. Use both for critical data.

### `ignore_changes`

Tells Terraform to **ignore differences** in certain attributes after
creation. Use it when something outside Terraform legitimately changes an
attribute:

```hcl
resource "google_compute_instance" "web" {
  # ...
  labels = {
    environment = "dev"
    last_backup = "never" # a backup tool updates this after each backup
  }

  lifecycle {
    ignore_changes = [
      labels["last_backup"],
      metadata["ssh-keys"], # managed by OS Login / users
    ]
  }
}
```

With the Google provider, `ignore_changes` on a label only matters for a
label you set in `labels`, like `last_backup` above. The provider compares
only those; a label that someone adds outside Terraform never shows up as a
change in the first place.

`ignore_changes = all` ignores every attribute — rarely a good idea.

### `replace_triggered_by`

Forces replacement of a resource when *another* resource or attribute
changes:

```hcl
resource "google_compute_instance" "web" {
  # ...
  lifecycle {
    replace_triggered_by = [
      terraform_data.app_version
    ]
  }
}

resource "terraform_data" "app_version" {
  input = var.app_version
}
```

Changing `var.app_version` changes `terraform_data.app_version`, which
replaces the VM. `terraform_data` is a built-in resource (no provider needed)
that just stores a value; it's handy exactly for this kind of trigger.

### Summary of lifecycle arguments

| Argument | Effect |
|---|---|
| `create_before_destroy` | Create replacement before destroying the old object. |
| `prevent_destroy` | Error on any plan that would destroy the resource. |
| `ignore_changes` | Ignore drift in listed attributes. |
| `replace_triggered_by` | Replace when referenced items change. |
| `precondition` / `postcondition` | Custom conditions (8.3). |

> **Exam tip:** Expect a scenario question for each lifecycle argument. "Avoid
> downtime when a replacement is needed" → `create_before_destroy`; "stop
> accidental deletion of a database" → `prevent_destroy`; "an external
> process modifies tags" → `ignore_changes`.

## Common mistakes and exam tips

* Writing a condition that returns `true` when something is *wrong*. The
  condition must be `true` when everything is *fine*.
* Vague error messages. Explain what's wrong *and* what's allowed.
* Expecting `check` to stop a deployment — it only warns.
* Thinking `prevent_destroy` survives deleting the resource block.
* Over-using `ignore_changes` to hide real drift.

## Summary

* `validation` checks input variables; `precondition` checks assumptions
  before an object; `postcondition` checks guarantees after it; all three
  stop Terraform with an error.
* `check` blocks run on every plan/apply and only warn.
* `lifecycle` controls replacement order, deletion protection, ignored
  attributes, and replacement triggers.

## Quick check

1. Which custom condition would you use to ensure a variable is one of a fixed
   set of values?
2. What keyword refers to the resource's own attributes in a postcondition?
3. What happens when a `check` block assertion fails?
4. A replacement of a load-balancer backend causes downtime. Which lifecycle
   argument helps?
5. You add `prevent_destroy = true` and then delete the whole resource block.
   What happens on the next apply?

---

## Hands-on exercise: Guard rails for a web server

**Goal:** Add validations, pre/postconditions, a check block, and lifecycle
rules to a small configuration, and watch them fire.

**Estimated time:** 25 minutes

**Files:** `code/ch08-conditions/exercise/`

### Steps

1. `cd code/ch08-conditions/exercise`, copy `terraform.tfvars.example` to
   `terraform.tfvars`, and set your project ID.
2. In `variables.tf`, add validation rules:
   * `environment` must be `dev`, `staging`, or `prod`.
   * `machine_type` must start with `e2-`.
   * `allowed_cidr` must be a valid CIDR (use `can(cidrhost(...))`).
3. In `main.tf`:
   * Add a postcondition on `data.google_compute_image.debian` that the
     image `status` is `"READY"`.
   * Add a precondition on the VM that `prod` cannot use `e2-micro`.
   * Add `prevent_destroy = true` to the bucket.
   * Add `ignore_changes` for `labels["owner"]` on the VM.
   * Add a `check` block with a scoped `http` data source that asserts the
     website returns status 200.
4. `terraform init` and `terraform apply`. Immediately after the first apply,
   the check probably **warns** (nginx is still installing). Wait a minute and
   run `terraform plan` — the warning disappears. The plan still lists
   `data.http.home` as "will be read during apply (config will be reloaded
   to verify a check block)" and ends with `Plan: 0 to add, 0 to change,
   0 to destroy` instead of "No changes": a check's data source is always
   read again during the apply.
5. Trigger each rule and read the messages:
   * `terraform plan -var environment=qa`
   * `terraform plan -var machine_type=n2-standard-2`
   * `terraform plan -var environment=prod`
   * `terraform plan -var allowed_cidr=banana`

   The `prod` plan shows a second error, `Instance cannot be destroyed`: the
   bucket name contains the environment, so renaming it means replacing it,
   and `prevent_destroy` forbids that.
6. Change the VM's `owner` label (set to `platform-team` in `main.tf`)
   outside Terraform:
   `gcloud compute instances add-labels ch08-web --labels=owner=alice --zone=<zone>`.
   Run `terraform plan` — no change proposed, thanks to `ignore_changes`.
   Comment out the `ignore_changes` line and plan again: now Terraform wants
   to set `owner` back from `alice` to `platform-team`. Restore the line.
7. Run `terraform destroy`. It fails because of `prevent_destroy`. Read the
   error.

### Expected result

Every invalid input is rejected with your own error message, and destroying
the bucket is blocked.

### Stretch goal

Add a `terraform_data` resource holding a `var.app_version` string and use
`replace_triggered_by` so that changing the version replaces the VM.

### Cleanup

Set `prevent_destroy = false` (or remove the line), then:

```console
$ terraform destroy
```

---

## Quick check answers

1. A `validation` block inside the variable (e.g. with `contains()`).
2. `self`.
3. Terraform prints a warning; the plan or apply continues.
4. `create_before_destroy = true`.
5. The resource is destroyed — `prevent_destroy` was removed along with the
   block, so it no longer protects anything.
