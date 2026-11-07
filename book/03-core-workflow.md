# Chapter 3 — Your First Configuration and the Core Workflow

## Learning objectives

By the end of this lesson you will be able to:

* Describe the Terraform workflow: **write → init → plan → apply → destroy**. `[3a]`
* Initialise a working directory with `terraform init`. `[3b]`
* Validate a configuration with `terraform validate`. `[3c]`
* Generate, read, and save an execution plan with `terraform plan`. `[3d]`
* Apply changes with `terraform apply`. `[3e]`
* Destroy infrastructure with `terraform destroy`. `[3f]`
* Format code with `terraform fmt`. `[3g]`

---

## 3.1 Anatomy of a Terraform configuration

A **configuration** is a set of files ending in `.tf` in one directory.
Terraform reads *all* `.tf` files in the directory and treats them as one
big file; the file names do not matter to Terraform. By convention, projects
use:

| File | Contents |
|---|---|
| `versions.tf` | The `terraform` block: required Terraform and provider versions. |
| `providers.tf` | Provider configuration (`provider "google" { ... }`). |
| `main.tf` | Resources. |
| `variables.tf` | Input variables (Chapter 6). |
| `outputs.tf` | Outputs (Chapter 6). |

The directory you run Terraform in is called the **working directory** or
**root module**.

### HCL syntax in two minutes

HCL is built from **blocks** and **arguments**:

```hcl
resource "google_storage_bucket" "notes" {   # block: type, then labels
  name     = "tf-book-notes-12345"            # argument: name = value
  location = "EU"

  versioning {                                # nested block
    enabled = true
  }
}
```

* A **block** has a *type* (`resource`), zero or more *labels*
  (`"google_storage_bucket"`, `"notes"`), and a body in `{ }`.
* An **argument** assigns a value to a name: `location = "EU"`.
* Values can be strings (`"EU"`), numbers (`3`), booleans (`true`), lists
  (`["a", "b"]`), and maps (`{ team = "web" }`).
* Comments start with `#` or `//`, or span lines between `/*` and `*/`.

### The resource block

The most important block is `resource`. Its two labels are:

1. The **resource type**, e.g. `google_storage_bucket`. The prefix before the
   first underscore (`google`) tells Terraform which provider handles it.
2. The **local name**, e.g. `notes`. You choose it. It is used to refer to the
   resource elsewhere in your code and must be unique per type within the
   module.

Together they form the resource's **address**: `google_storage_bucket.notes`.

## 3.2 Your first configuration

Create a new folder and three files.

**`versions.tf`**

```hcl
terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
  }
}
```

This tells Terraform: "I need Terraform 1.17.x and exactly version 8.9.0 of
the Google provider from the public Terraform Registry." Chapter 4 explains
version constraints in detail.

**`providers.tf`**

```hcl
provider "google" {
  project = "tf-book-fatih-12345" # your project ID
  region  = "europe-west1"
}
```

The provider block sets defaults used by all Google resources: which project
and which region. Pick a region near you (for example `us-central1`,
`europe-west1`, `asia-southeast1`). The default region applies to regional
resources such as VMs; it does not decide where the bucket below lives. That
is set by the bucket's own `location` argument.

**`main.tf`**

```hcl
resource "google_storage_bucket" "notes" {
  name                        = "tf-book-fatih-12345-notes"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true
}
```

This creates a **Cloud Storage bucket** — a container for files in the cloud.

* `uniform_bucket_level_access = true` is the recommended, simpler
  permission model.
* `force_destroy = true` lets Terraform delete the bucket even if it contains
  files. Handy for learning; think twice before using it in production.

Bucket names are **globally unique** across all Google Cloud customers, so
include your project ID in the name.

Why does that help? A bucket name like `notes` is almost certainly taken by
someone already, and `terraform apply` would fail with an error saying the
name isn't available. Your project ID, however, is already unique: Google
only let you create your project in section 2.4 because no one else in the
world had that ID. Other people don't use your project ID in their bucket names,
so `tf-book-fatih-12345-notes` is very unlikely to be taken. The suffix
(`-notes`) then keeps it apart from your own other buckets.

This is a naming convention, not a rule Google enforces: nothing stops a
stranger from creating a bucket with your project ID in its name. In practice
nobody does, which is why the convention is so widely used. (The one name
format Google *does* protect is a domain name, such as `assets.example.com`:
you must prove you own the domain before you can use it as a bucket name.)

**Alternative: a random suffix.** Instead of the project ID, you can let
Terraform generate a random suffix with the `random` provider. Add it to
`versions.tf`:

```hcl
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
```

and use it in `main.tf`:

```hcl
resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "notes" {
  name                        = "notes-${random_id.suffix.hex}" # e.g. notes-8f3a1c2b
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true
}
```

`random_id` generates 4 random bytes, written as 8 hexadecimal characters:
about 4 billion possible values, so a collision is extremely unlikely. The
value is generated **once**, on the first `terraform apply`, and then stored
in the state file; later runs reuse it, so the bucket name doesn't change
every time. Run `terraform init` again after adding the provider.

Which one to choose?

* **Project ID:** readable, and you can tell from the name which project a
  bucket belongs to. Best when one bucket per purpose and project is enough.
* **Random suffix:** works when you need several similar buckets (for
  example in many environments or in tests), and keeps the project ID out of
  the name. The downside is that you can't guess the name; read it from the
  `apply` output, `terraform state show google_storage_bucket.notes`, or the
  console. (Chapter 6 shows how to print it with an output.)

Chapter 4 covers the `random` provider in more detail. The rest of this
chapter uses the project ID version.

## 3.3 `terraform init` — prepare the working directory `[3b]`

Before anything else, run `init`:

```console
$ terraform init
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/google versions matching "8.9.0"...
- Installing hashicorp/google v8.9.0...
- Installed hashicorp/google v8.9.0 (signed by HashiCorp)
Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!
```

`init` does three things:

1. **Initialises the backend** — where state will be stored (local by default;
   Chapter 10 moves it to Cloud Storage).
2. **Downloads providers** into a hidden `.terraform/` folder and writes the
   **dependency lock file** `.terraform.lock.hcl`.
3. **Downloads modules** if the configuration uses any (Chapter 12).

You must re-run `init` whenever you add a provider or module, change a
version constraint, or change the backend. It is always safe to run it again.

> **Exam tip:** `terraform init` is the *first* command to run in a new or
> freshly cloned working directory. Commands like `plan` fail with
> "Inconsistent dependency lock file" or "Required plugins are not installed"
> if you skip it.

What goes into Git?

| Path | Commit? |
|---|---|
| `*.tf` | Yes |
| `.terraform.lock.hcl` | **Yes** — guarantees everyone uses the same provider builds |
| `.terraform/` | **No** — downloaded plugins, recreated by `init` |
| `terraform.tfstate*` | **No** — may contain secrets (Chapter 9) |

A typical `.gitignore` (`tfplan` matches the plan file name used in this
chapter; `*.tfplan` covers names like `prod.tfplan`):

```gitignore
.terraform/
*.tfstate
*.tfstate.*
crash.log
tfplan
*.tfplan
override.tf
override.tf.json
*_override.tf
*_override.tf.json
```

## 3.4 `terraform fmt` — consistent style `[3g]`

```console
$ terraform fmt
main.tf
```

`fmt` rewrites files into the canonical Terraform style: two-space indents,
aligned equals signs, consistent spacing. It prints the names of files it
changed. Useful flags:

| Command | Effect |
|---|---|
| `terraform fmt` | Format files in the current directory. |
| `terraform fmt -recursive` | Also format sub-directories (modules). |
| `terraform fmt -check` | Don't change anything; list the files that need formatting and exit with a non-zero code (3). Perfect for CI. |
| `terraform fmt -diff` | Format the files **and** show the changes made. |
| `terraform fmt -check -diff` | Show what would change without changing anything. |

Formatting never changes the *meaning* of your code, only its layout.

## 3.5 `terraform validate` — catch mistakes early `[3c]`

```console
$ terraform validate
Success! The configuration is valid.
```

`validate` checks that the configuration is **syntactically valid and
internally consistent**: correct block structure, known argument names,
correct types, references that point to things that exist. It does *not*
contact Google Cloud, so it cannot tell you that a bucket name is already
taken. It needs `init` to have run first (so it knows the provider's schema).

Try introducing an error — misspell `location` as `locaton` — and run
`validate` again:

```console
$ terraform validate
╷
│ Error: Unsupported argument
│
│   on main.tf line 3, in resource "google_storage_bucket" "notes":
│    3:   locaton  = "EU"
│
│ An argument named "locaton" is not expected here. Did you mean "location"?
╵
```

Fix it before continuing.

## 3.6 `terraform plan` — preview the changes `[3d]`

```console
$ terraform plan

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # google_storage_bucket.notes will be created
  + resource "google_storage_bucket" "notes" {
      + force_destroy               = true
      + id                          = (known after apply)
      + location                    = "EU"
      + name                        = "tf-book-fatih-12345-notes"
      + project                     = "tf-book-fatih-12345"
      + self_link                   = (known after apply)
      + storage_class               = "STANDARD"
      + uniform_bucket_level_access = true
      + url                         = (known after apply)
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

How to read a plan:

| Symbol | Meaning |
|---|---|
| `+` | create |
| `-` | destroy |
| `~` | update in place |
| `-/+` | destroy and then re-create (replacement) |
| `+/-` | create the replacement first, then destroy the old one |
| `<=` | read (a data source) |

* `(known after apply)` means the value is only known once the resource
  exists (for example, an ID generated by Google).
* The last line summarises the changes. **Always read it.** An unexpected
  "1 to destroy" is your cue to stop and investigate.

Under the hood, `plan`:

1. **Refreshes** — reads the current state of existing resources from Google
   Cloud.
2. **Compares** the desired configuration with the current state.
3. **Proposes** the actions needed to make reality match the configuration.

`plan` never changes real infrastructure.

### Saving a plan

You can save a plan to a file and apply exactly that plan later:

```console
$ terraform plan -out=tfplan
$ terraform apply tfplan
```

When you apply a saved plan, Terraform does **not** ask for confirmation and
does exactly what the plan says — nothing more. If the **state** changed in
the meantime (for example, someone else ran `apply`), the plan is *stale* and
Terraform refuses to apply it. Changes made outside Terraform, such as an
edit in the console, are not detected this way; they can make the apply fail
or be silently overwritten. This is how
CI/CD pipelines make sure that what was reviewed is what gets applied. (The
apply can still *fail* — for example on a missing permission or a quota — as
the warning in section 1.4 explains.)

The plan file is binary. To read it:

```console
$ terraform show tfplan            # human-readable
$ terraform show -json tfplan      # machine-readable (used in Chapter 20)
```

> **Security tip:** Saved plan files can contain sensitive values. Don't
> commit them to Git.

### Other useful plan flags

| Flag | Purpose |
|---|---|
| `-destroy` | Show what `destroy` would do. |
| `-var 'name=value'` / `-var-file=FILE` | Set input variables (Chapter 6). |
| `-target=ADDRESS` | Plan only one resource and its dependencies. For emergencies only. |
| `-refresh-only` | Only detect drift; propose no changes to resources (Chapter 11). |
| `-refresh=false` | Skip reading real infrastructure (faster, but riskier). |
| `-replace=ADDRESS` | Force a resource to be destroyed and re-created (Chapter 11). |
| `-detailed-exitcode` | Exit code 0 = no changes, 1 = error, 2 = changes present. Useful in scripts. |

## 3.7 `terraform apply` — make it real `[3e]`

```console
$ terraform apply
...
Plan: 1 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

google_storage_bucket.notes: Creating...
google_storage_bucket.notes: Creation complete after 2s [id=tf-book-fatih-12345-notes]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

Without a saved plan file, `apply` first creates a new plan, shows it, and
asks you to type **`yes`** (exactly — `y` is not accepted). Use
`-auto-approve` to skip the question; reserve it for automation.

Check the bucket exists:

```console
$ gcloud storage buckets list --format="value(name)"
tf-book-fatih-12345-notes
```

Notice the new file `terraform.tfstate` in your directory. That is Terraform's
**state**: its record of what it created. Never edit it by hand. Chapter 9
covers it in detail.

### Idempotency in action

Run `terraform apply` again:

```console
$ terraform apply
google_storage_bucket.notes: Refreshing state... [id=tf-book-fatih-12345-notes]

No changes. Your infrastructure matches the configuration.
```

Nothing to do — reality already matches the code.

### Making a change

Add a label to the bucket in `main.tf`:

```hcl
resource "google_storage_bucket" "notes" {
  name                        = "tf-book-fatih-12345-notes"
  location                    = "EU"
  uniform_bucket_level_access = true
  force_destroy               = true

  labels = {
    course = "terraform-book"
  }
}
```

```console
$ terraform plan
  # google_storage_bucket.notes will be updated in-place
  ~ resource "google_storage_bucket" "notes" {
        id     = "tf-book-fatih-12345-notes"
      ~ labels = {
          + "course" = "terraform-book"
        }
        ...
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

The `~` means Terraform will update the existing bucket in place. Now change
`location` from `"EU"` to `"US"` and plan again:

```console
  # google_storage_bucket.notes must be replaced
-/+ resource "google_storage_bucket" "notes" {
      ~ location = "EU" -> "US" # forces replacement
      ...
Plan: 1 to add, 0 to change, 1 to destroy.
```

A bucket's location cannot be changed after creation, so Terraform must
**destroy and re-create** it. The plan marks the responsible argument with
`# forces replacement`. In production, replacement could mean data loss —
this is why you always read the plan. Change the location back to `"EU"`
before continuing.

## 3.8 `terraform destroy` — clean up `[3f]`

```console
$ terraform destroy
...
  # google_storage_bucket.notes will be destroyed
  - resource "google_storage_bucket" "notes" {
...
Plan: 0 to add, 0 to change, 1 to destroy.

Do you really want to destroy all resources?
  Enter a value: yes

google_storage_bucket.notes: Destroying... [id=tf-book-fatih-12345-notes]
google_storage_bucket.notes: Destruction complete after 1s

Destroy complete! Resources: 1 destroyed.
```

`destroy` removes **every resource managed by this configuration** (and only
those — it never touches resources Terraform does not know about). One
exception to watch: with `force_destroy = true`, deleting a bucket also
deletes every object in it, including files you uploaded by hand that
Terraform never managed.
`terraform destroy` is an alias for `terraform apply -destroy`. To preview it
without destroying, use `terraform plan -destroy`.

To remove just one resource permanently, the normal way is to **delete it from
the configuration** and run `apply`. `terraform destroy -target=ADDRESS`
exists but should be rare.

## 3.9 The complete workflow

```
        ┌──────────┐
        │  Write   │◀──────────────────────────┐
        └────┬─────┘                           │
             ▼                                 │
  init (once, or after provider/module/backend changes)
             ▼                                 │
  fmt  →  validate  →  plan  →  apply  ────────┘
                                   │
                         (when finished) destroy
```

> **Exam tip:** Know the order and purpose of each command. A favourite
> question: "Which command(s) do NOT modify infrastructure?" Answer: `init`,
> `fmt`, `validate`, `plan`, `show`, `output`, `state list`, and also
> `import`. Only `apply` and `destroy` change real infrastructure; `import`
> and the `state` commands change the **state file** only (Chapters 9 and 11).

## Common mistakes and exam tips

* **Typing `y` instead of `yes`** — Terraform cancels the apply.
* **Skipping `init`** after adding a provider — you get "provider not
  installed" errors.
* **Assuming `validate` checks the cloud** — it doesn't; only commands that
  read or change resources (`plan`, `apply`, `destroy`, `import`) talk to the
  API.
* **Not reading the plan** — especially lines saying `forces replacement`.
* **Committing `terraform.tfstate` or `.terraform/` to Git.**
* `terraform fmt -check` returns a non-zero exit code if formatting is needed;
  it doesn't modify files.
* `apply` with a saved plan file **does not** ask for approval.

## Summary

* A configuration is all the `.tf` files in a directory, written in HCL using
  blocks and arguments.
* `init` downloads providers and modules and sets up the backend.
* `fmt` formats, `validate` checks syntax and consistency locally.
* `plan` previews changes; `apply` executes them; `destroy` removes
  everything the configuration manages.
* Read plan symbols carefully: `+`, `-`, `~`, `-/+`.

## Quick check

1. What three things does `terraform init` do?
2. Which command would you run in CI to fail the build if code isn't
   formatted?
3. You saved a plan with `-out=tfplan`. What happens when you run
   `terraform apply tfplan`?
4. What does `-/+` mean in a plan?
5. Should `.terraform.lock.hcl` be committed to version control?

---

## Hands-on exercise: Your first bucket, end to end

**Goal:** Create, change, and destroy a Cloud Storage bucket using the full
Terraform workflow.

**Estimated time:** 25 minutes

**Files:** `code/ch03-core-workflow/exercise/`

### Steps

1. `cd code/ch03-core-workflow/exercise`.
2. In `providers.tf`, replace `TODO-your-project-id` with your project ID
   (`TODO (step 2)`).
3. In `main.tf`, complete the `TODO (step 3)` items to define a bucket named
   `<your-project-id>-ch03` in location `EU` (or `US`) with uniform
   bucket-level access and `force_destroy = true`.
4. The file is deliberately badly formatted. Run `terraform fmt -check -diff`
   to preview the changes and check the exit code with `echo $?` (it prints
   `3`, meaning "files need formatting"; `0` means all is well). Then run
   `terraform fmt`, and open the file to see what changed.
5. A copy of `.terraform.lock.hcl` is already in the folder, so `init` would
   simply use it. To watch `init` create one, delete it first
   (`rm .terraform.lock.hcl`), then run `terraform init` and open the new
   file. Compare it with the copy in `../solution/`: the provider version
   should be the same.
6. Run `terraform validate`.
7. Run `terraform plan -out=tfplan`, then `terraform show tfplan`, then
   `terraform apply tfplan`. Note that no confirmation was requested.
8. Upload a file: `echo hello > hello.txt && gcloud storage cp hello.txt gs://<bucket-name>/`.
9. Add a label `environment = "learning"` and enable `versioning`. Plan and
   apply. Confirm the plan shows an **in-place update** (`~`).
10. Change `storage_class` to `"NEARLINE"`. Is this an update or a
    replacement? Apply it. (NEARLINE is cheaper for storage but has a 30-day
    minimum storage charge; for one tiny file that is a fraction of a cent.
    Note that changing the bucket's default class doesn't change the class of
    objects already in it, such as `hello.txt`.)
11. Run `terraform apply` once more and confirm "No changes".

### Expected result

A bucket with your labels, versioning enabled, and the NEARLINE storage class,
visible in `gcloud storage buckets describe gs://<bucket-name>`.

### Stretch goal

Run `terraform plan -detailed-exitcode` before and after making a change, and
print `echo $?` each time. Which exit codes do you see, and how could a
script use them?

### Cleanup

```console
$ terraform destroy
$ rm tfplan hello.txt
```

Type `yes`. Thanks to `force_destroy = true`, the bucket is deleted together
with `hello.txt` and its versions. Confirm the bucket is gone with
`gcloud storage buckets list`. The `rm` removes the saved plan and the test
file from your working folder.

Answers to step 10 and the stretch goal are in
`code/ch03-core-workflow/solution/answers.md`.

---

## Quick check answers

1. Initialises the backend, downloads providers (and writes the lock file),
   downloads modules.
2. `terraform fmt -check` (often with `-recursive`).
3. Terraform applies exactly that plan without asking for confirmation (and
   refuses if the state has changed since the plan was made, i.e. the plan is
   stale).
4. The resource will be destroyed and then re-created (replaced).
5. Yes.
