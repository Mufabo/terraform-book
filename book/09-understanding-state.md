# Chapter 9 — Understanding State

## Learning objectives

By the end of this lesson you will be able to:

* Explain what Terraform state is and why Terraform needs it. `[2d]`
* Describe the **local backend** and the files it creates. `[6a]`
* Explain **state locking** and what to do about a stuck lock. `[6b]`
* Inspect state with `terraform show`, `terraform state list`, and
  `terraform state show`. `[7b]`
* Modify state safely with `terraform state mv` and `terraform state rm`. `[7b]`
* Explain why state must be protected (it can contain secrets). `[2d]`

**Time:** about 45 minutes — 15 reading, 5 quick check, 25 exercise.

---

## 9.1 What is state? `[2d]`

When you ran `terraform apply` in Chapter 3, a file called
`terraform.tfstate` appeared. That file is Terraform's **state**: a JSON
document that records every object Terraform manages and how it maps to your
configuration.

```
   configuration              state                      real world
 ┌──────────────────┐   ┌────────────────────────┐   ┌──────────────────────┐
 │ resource         │   │ google_storage_bucket. │   │ gs://tf-book-...-ch09│
 │ "google_storage_ │──▶│ notes                  │──▶│ (a real bucket)      │
 │  bucket" "notes" │   │ id = "tf-book-...-ch09"│   │                      │
 └──────────────────┘   │ location = "EU" ...    │   └──────────────────────┘
                        └────────────────────────┘
```

### Why does Terraform need state?

1. **Mapping configuration to real objects.** Your code says
   `google_storage_bucket.notes`. Which actual bucket is that? Many
   resources have no unique name you could look up (a firewall rule ID, a
   random value). State stores the ID of each real object.
2. **Tracking metadata, including dependencies.** When you delete a resource
   block from the configuration, Terraform no longer has the code — but it
   needs to know the resource existed, which provider manages it, and in which
   order to destroy things. State remembers.
3. **Performance.** State caches attribute values. For large infrastructures,
   Terraform can skip refreshing (`-refresh=false`) and rely on the cache.
4. **Collaboration.** When state is stored remotely (Chapter 10), everyone on
   a team works from the same record.

### What plan really compares

During `plan`, Terraform:

1. **Refreshes** state: for each object in state, asks the provider for its
   current real-world attributes.
2. **Compares** the refreshed state with the configuration.
3. **Proposes** actions to make reality match the configuration.

So state is not the *desired* state (that's your code); it is Terraform's
record of the *actual* state, as of the last time it looked.

## 9.2 Inside the state file

```json
{
  "version": 4,
  "terraform_version": "1.17.0",
  "serial": 3,
  "lineage": "8a4b2c1e-...",
  "outputs": {
    "bucket_url": { "value": "gs://tf-book-fatih-12345-ch09", "type": "string" }
  },
  "resources": [
    {
      "mode": "managed",
      "type": "google_storage_bucket",
      "name": "notes",
      "provider": "provider[\"registry.terraform.io/hashicorp/google\"]",
      "instances": [
        {
          "attributes": {
            "id": "tf-book-fatih-12345-ch09",
            "location": "EU",
            "name": "tf-book-fatih-12345-ch09",
            ...
          },
          "dependencies": []
        }
      ]
    }
  ]
}
```

* `serial` increases with every change; `lineage` is a unique ID for this
  state's history. Together they prevent mixing up different states.
* `mode` is `managed` for resources and `data` for data sources.
* Every attribute is stored — **including sensitive ones** such as passwords
  or private keys.

> **Never edit the state file by hand.** Use the `terraform state` commands
> described below. A malformed state file can make Terraform lose track of
> your infrastructure.

### State contains secrets `[2d]`

If a resource has a password attribute, or you read a secret with a data
source, the value is stored **in plain text** in state. Marking a variable or
output `sensitive` only hides it from the terminal output. Therefore:

* Never commit state to Git.
* Store it in a backend that encrypts it at rest and restricts access
  (Chapter 10: a Google Cloud Storage bucket with tight IAM).
* Prefer ephemeral values and write-only arguments, which are never stored
  in state (Chapter 14).

## 9.3 The local backend `[6a]`

A **backend** determines where state is stored. If you don't configure one,
Terraform uses the **local backend**: state lives in a file on your disk.

| File | Purpose |
|---|---|
| `terraform.tfstate` | The current state. |
| `terraform.tfstate.backup` | The previous state, written before each change. |
| `.terraform.tfstate.lock.info` | Present only while an operation holds the lock. |

You can configure the local backend explicitly, for example to change the
path:

```hcl
terraform {
  backend "local" {
    path = "state/terraform.tfstate"
  }
}
```

The local backend is fine for learning and solo experiments. It is **not**
suitable for teams:

* State lives on one laptop — colleagues can't use it, and a lost laptop
  means lost state.
* No shared locking across machines.
* No encryption or access control beyond your file system.

Chapter 10 moves state to Cloud Storage.

## 9.4 State locking `[6b]`

What if two people run `terraform apply` at the same time against the same
state? Both read the same starting point, both make changes, and the last one
to write overwrites the other's state. Resources get "lost".

To prevent this, Terraform **locks** the state for all operations that could
write it (`plan`, `apply`, `destroy`, `import`, `state` commands, …). While
the lock is held, other operations wait or fail:

```console
$ terraform apply
╷
│ Error: Error acquiring the state lock
│
│ Error message: resource temporarily unavailable
│ Lock Info:
│   ID:        4f6d9a5e-1b2c-...
│   Path:      terraform.tfstate
│   Operation: OperationTypeApply
│   Who:       alice@laptop
│   Version:   1.17.0
│   Created:   2026-10-28 10:14:03 UTC
╵
```

* Locking happens **automatically** if the backend supports it. The local
  backend uses a lock file and OS-level locks; the GCS backend uses a lock
  object in the bucket.
* `-lock-timeout=60s` tells Terraform to wait for the lock instead of failing
  immediately — useful in CI.
* `-lock=false` disables locking. Don't.

### Stuck locks

If Terraform crashes or loses network connection mid-operation, the lock may
remain. After **confirming nobody is running Terraform**, release it with
the lock ID from the error message:

```console
$ terraform force-unlock 4f6d9a5e-1b2c-...
```

> **Exam tip:** `force-unlock` only removes the lock; it doesn't touch the
> state itself. It requires the lock ID. Use it only when you are sure the
> lock holder is gone.

## 9.5 Inspecting state `[7b]`

### `terraform show`

Prints the whole current state (or a saved plan) in human-readable form:

```console
$ terraform show
# google_storage_bucket.notes:
resource "google_storage_bucket" "notes" {
    id       = "tf-book-fatih-12345-ch09"
    location = "EU"
    ...
}
```

`terraform show -json` prints machine-readable JSON.

### `terraform state list`

Lists the address of every resource in state:

```console
$ terraform state list
data.google_project.current
google_storage_bucket.notes
google_storage_bucket.this["backups"]
google_storage_bucket.this["logs"]
random_id.suffix
```

Filter by address prefix: `terraform state list 'google_storage_bucket.this'`.

### `terraform state show`

Shows all attributes of one resource:

```console
$ terraform state show 'google_storage_bucket.this["logs"]'
```

Quote addresses that contain brackets or quotes so your shell doesn't
interpret them.

### `terraform output`

Reads output values from state (Chapter 6).

### `terraform state pull`

Prints the raw state JSON — useful with `jq`, and it works with remote
backends too:

```console
$ terraform state pull | jq '.resources[].type'
```

## 9.6 Modifying state `[7b]`

Sometimes you need to change state without changing real infrastructure.

### `terraform state mv` — rename or move

You renamed a resource in your code from `notes` to `docs`. Terraform sees
"delete `notes`, create `docs`" — it would destroy and re-create the bucket!
Tell Terraform it's the same object:

```console
$ terraform state mv google_storage_bucket.notes google_storage_bucket.docs
Move "google_storage_bucket.notes" to "google_storage_bucket.docs"
Successfully moved 1 object(s).
```

Now `plan` shows no changes. `state mv` also moves resources into or out of
modules and between `count`/`for_each` keys.

> **Better alternative:** The `moved` block (Chapter 11) does the same thing
> declaratively in code, so it's reviewed, versioned, and applied by everyone
> automatically. Prefer `moved` blocks; use `state mv` for one-off fixes.

### `terraform state rm` — forget a resource

```console
$ terraform state rm google_storage_bucket.legacy
Removed google_storage_bucket.legacy
Successfully removed 1 resource instance(s).
```

Terraform **forgets** the object; the real bucket keeps existing. Use it when
you want to stop managing something with Terraform (or hand it over to
another configuration). If the resource block is still in the configuration,
the next plan proposes to *create* a new one.

> **Better alternative:** The `removed` block (Chapter 11) is the declarative
> way to do this.

### `terraform state push`

Overwrites the state with a local file. Dangerous; used only for disaster
recovery. Terraform refuses if the `lineage` differs or the `serial` is
older, unless you add `-force`.

### Safety net

Every command that modifies state writes a backup first (for the local
backend, `terraform.tfstate.backup` or a timestamped backup file). With
remote backends, enable versioning on the bucket (Chapter 10).

## 9.7 Refreshing

`terraform apply -refresh-only` updates state to match the real world
*without* changing any infrastructure — for example after someone changed a
label in the console. Chapter 11 covers drift in depth. (The old
`terraform refresh` command still exists but is deprecated because it updates
state without showing you what will change.)

## Common mistakes and exam tips

* Editing `terraform.tfstate` manually.
* Committing state to Git (it contains secrets).
* Running `state rm` and expecting the cloud resource to disappear — it
  doesn't.
* Using `force-unlock` while someone is actually running Terraform.
* State is required; Terraform can't work without it. It is not optional
  caching.
* `terraform state list` and `terraform show` don't modify anything.

## Summary

* State maps configuration to real objects and stores metadata and
  dependencies.
* The local backend stores state in `terraform.tfstate` with a backup file.
* State locking prevents concurrent writes; `force-unlock` removes stale locks.
* Inspect with `show`, `state list`, `state show`, `state pull`; modify with
  `state mv` and `state rm` (or the declarative `moved` and `removed`
  blocks).
* State may contain secrets — protect it.

## Quick check

1. Give two reasons why Terraform needs state.
2. What does `terraform state rm` do to the real infrastructure?
3. Two colleagues run `terraform apply` simultaneously against the same
   remote state. What prevents corruption?
4. Which command shows all attributes of a single resource from state?
5. What is the risk of storing state in a Git repository?

---

## Hands-on exercise: Exploring and changing state

**Goal:** Inspect a local state file and use state commands to rename and
forget resources without touching real infrastructure.

**Estimated time:** 25 minutes

**Files:** `code/ch09-state/exercise/`

### Steps

1. `cd code/ch09-state/exercise`, create `terraform.tfvars` from the example,
   `terraform init`, and `terraform apply`. The configuration creates a
   `random_id`, a bucket `notes`, and two buckets from a `for_each` set.
2. Open `terraform.tfstate` in your editor (read only!). Find the `serial`,
   the `lineage`, and the bucket IDs.
3. Run and compare:

   ```console
   $ terraform state list
   $ terraform state show google_storage_bucket.notes
   $ terraform show
   $ terraform state pull | jq '.serial'
   ```

4. **Locking:** In one terminal, run
   `terraform apply -var 'buckets=["logs", "archive", "extra"]'` and leave it
   waiting at the "Enter a value" prompt. (The extra bucket gives `apply`
   something to do; with no changes it would finish at once without asking.)
   In a second terminal, run `terraform plan`. Read the lock error. Then try
   `terraform plan -lock-timeout=30s` and answer the first prompt with `no`
   within 30 seconds — the second command proceeds.
5. **Rename:** In `main.tf`, rename `google_storage_bucket.notes` to
   `google_storage_bucket.docs` (and its references in `outputs.tf`). Run
   `terraform plan` — it wants to destroy and create! Now run
   `terraform state mv google_storage_bucket.notes google_storage_bucket.docs`
   and plan again: no changes. (If you also renamed the output to
   `docs_bucket`, as the solution does, the plan shows only "Changes to
   Outputs". Run `terraform apply` to save the new output name; no
   infrastructure changes.)
6. **Forget:** Run `terraform state rm 'google_storage_bucket.this["archive"]'`.
   Confirm the bucket still exists with `gcloud storage ls`. Run
   `terraform plan`: Terraform wants to create it again (and would fail,
   because the name is taken). Remove the `archive` entry from
   `terraform.tfvars` so Terraform no longer manages it. `terraform plan` now
   shows only "Changes to Outputs": the `other_buckets` output saved in state
   still lists the archive bucket. Run `terraform apply` to update it. Delete
   the bucket with `gcloud storage rm -r gs://<name>`.
7. Look at the `serial` again. How many times did it change?

### Expected result

You renamed a resource and stopped managing another without recreating
anything, and you've seen a state lock in action.

### Stretch goal

Look inside `terraform.tfstate.backup`. Which serial does it have?

### Cleanup

```console
$ terraform destroy
```

---

## Quick check answers

1. Any two of: mapping config to real objects, tracking metadata and
   dependencies (e.g. for deleted resources), performance (caching), team
   collaboration.
2. Nothing; it only removes the object from state. The real resource keeps
   running, unmanaged.
3. State locking (supported by the remote backend, e.g. GCS).
4. `terraform state show <address>`.
5. State can contain secrets in plain text, Git has no locking, and it's easy
   to commit stale or conflicting versions.
