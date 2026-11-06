# Chapter 4 — Providers

## Learning objectives

By the end of this lesson you will be able to:

* Explain how Terraform uses providers and where they come from. `[2b]`
* Install and version providers using `required_providers` and version
  constraints. `[2a]`
* Explain the purpose of the dependency lock file and upgrade providers safely. `[2a]`
* Configure providers, including multiple configurations of the same provider
  with **aliases**. `[2c]`
* Write a configuration that uses several providers (`google`,
  `google-beta`, `random`). `[2c]`

---

## 4.1 What a provider is `[2b]`

Terraform Core doesn't know anything about Google Cloud, AWS, or GitHub. All
of that knowledge lives in **providers**: separate plugin programs that
Terraform downloads and runs.

A provider:

* **Defines resource types and data sources**, e.g. `google_storage_bucket`,
  `google_compute_instance`, and their arguments and attributes (the
  *schema*).
* **Translates** Terraform's requests ("create this bucket with these
  settings") into API calls (`POST https://storage.googleapis.com/storage/v1/b`).
* **Handles authentication** with the target platform.

When you run `terraform plan`, Core starts each provider as a separate process
and talks to it over a local RPC protocol. Providers are released and
versioned **independently** of Terraform itself — `hashicorp/google` 8.9.0
works with Terraform 1.17.0, and many other versions.

## 4.2 The Terraform Registry

Providers are published to the **Terraform Registry** at
<https://registry.terraform.io>. Each provider page has documentation for
every resource — you will spend a lot of time there. Providers come in tiers:

| Tier | Maintained by | Examples |
|---|---|---|
| **Official** | HashiCorp | `hashicorp/google`, `hashicorp/aws`, `hashicorp/random` |
| **Partner** | Technology companies, verified by HashiCorp | `cloudflare/cloudflare`, `datadog/datadog` |
| **Community** | Individuals and groups | many |

The Google provider is developed jointly by Google and HashiCorp. There are
two variants:

* **`hashicorp/google`** — generally available (GA) Google Cloud features.
* **`hashicorp/google-beta`** — GA *plus* beta features. Use it only for
  resources or arguments that require it.

### Provider source addresses

Every provider has a **source address** in the format
`[HOSTNAME/]NAMESPACE/TYPE`:

```
registry.terraform.io/hashicorp/google
└───────┬───────────┘ └───┬───┘ └──┬─┘
     hostname         namespace   type
```

The hostname defaults to `registry.terraform.io`, so you usually write just
`hashicorp/google`. Private registries (for example in HCP Terraform, Chapter
17) use a different hostname.

## 4.3 Declaring providers: `required_providers` `[2a]`

You declare which providers your configuration needs in the `terraform`
block:

```hcl
terraform {
  required_version = "~> 1.17.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.1"
    }
  }
}
```

* The key (`google`, `random`) is the **local name**. It's the prefix used by
  resource types (`google_storage_bucket`, `random_id`) and the label of the
  `provider` block.
* `source` says where to download the provider.
* `version` is a **version constraint**.

If you use a resource without declaring its provider, Terraform guesses
`hashicorp/<prefix>`. That works for HashiCorp providers but is bad practice
— always declare providers explicitly.

### Version constraints

| Operator | Meaning | Example | Allows |
|---|---|---|---|
| `=` or none | Exactly this version | `"8.9.0"` | 8.9.0 only |
| `!=` | Exclude a version | `"!= 8.8.0"` | anything except 8.8.0 |
| `>`, `>=`, `<`, `<=` | Comparisons | `">= 8.0.0, < 9.0.0"` | 8.x |
| `~>` | **Pessimistic constraint**: only the right-most number may increase | `"~> 8.9.0"` | 8.9.0, 8.9.1, … not 8.10.0 |
| | | `"~> 8.9"` | 8.9, 8.10, 8.11, … not 9.0 |

Combine constraints with commas: `">= 8.5.0, < 9.0.0"`.

> **Exam tip:** `~>` questions are classic. `~> 1.2.0` means `>= 1.2.0, < 1.3.0`.
> `~> 1.2` means `>= 1.2, < 2.0`. Only the *last* number in the constraint
> may increase.

**Which style should you use?**

* **Root modules** (the configurations you apply, like this book's
  exercises): pin tightly — an exact version or `~> X.Y.0`. The lock file
  gives an additional guarantee.
* **Reusable modules** (Chapter 13): use a *minimum* version, e.g.
  `">= 8.0"`, so the module works in many root configurations.

`required_version` uses the same operators to constrain the Terraform CLI
version. Running with a version outside the range fails immediately with
"Unsupported Terraform Core version".

> **Newer than the exam:** Terraform 1.17 allows variables and locals inside
> provider requirements. The exam assumes literal values, and literal values
> remain the clearest choice.

## 4.4 The dependency lock file `[2a]`

After `init`, Terraform writes `.terraform.lock.hcl`:

```hcl
provider "registry.terraform.io/hashicorp/google" {
  version     = "8.9.0"
  constraints = "8.9.0"
  hashes = [
    "h1:Abc123...",
    "zh:0f4e...",
    ...
  ]
}
```

It records:

* the **exact version** selected for each provider, and
* **checksums** of the provider packages.

On subsequent `init` runs, Terraform installs exactly the recorded version
(as long as it still satisfies your constraints) and verifies the checksum.
If someone tampered with the download, `init` fails. Commit this file to Git
so your colleagues and CI get identical providers.

The lock file only covers **providers**, not modules.

### Upgrading providers

Even if you loosen a constraint to `~> 8.9`, Terraform keeps using the version
in the lock file. To deliberately move to a newer version allowed by your
constraints:

```console
$ terraform init -upgrade
- Finding hashicorp/google versions matching "~> 8.9"...
- Installing hashicorp/google v8.10.0...
```

`-upgrade` ignores the lock file's versions, picks the newest allowed version,
and updates the lock file. Review the provider's changelog, run `plan`, and
commit the lock file change.

### Lock files and multiple platforms

The lock file contains checksums for the platform where you ran `init`
(e.g. `linux_amd64`). If teammates use macOS on Apple Silicon, add their
checksums too:

```console
$ terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64
```

### Inspecting providers

```console
$ terraform providers

Providers required by configuration:
.
├── provider[registry.terraform.io/hashicorp/google] 8.9.0
└── provider[registry.terraform.io/hashicorp/random] 3.9.1
```

`terraform version` also lists installed providers.

### Where providers are stored

`init` downloads providers to `.terraform/providers/` in each working
directory. To avoid re-downloading the same provider for every project, set a
shared plugin cache in `~/.terraformrc`:

```hcl
plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
```

(Create the directory first.) Air-gapped environments can use a local
**provider mirror** instead of the public registry.

## 4.5 Configuring providers `[2b]`

The `provider` block configures a provider:

```hcl
provider "google" {
  project = "tf-book-fatih-12345"
  region  = "europe-west1"
  zone    = "europe-west1-b"

  default_labels = {
    managed_by = "terraform"
  }
}
```

* `project`, `region`, `zone` are **defaults**. Individual resources can
  override them with their own `project`, `region`, or `zone` arguments.
* `default_labels` adds labels to every resource that supports them — great
  for cost tracking.
* **Credentials are not in the block.** The provider finds Application Default
  Credentials automatically (Chapter 2). Many settings can also come from
  environment variables such as `GOOGLE_PROJECT` and `GOOGLE_REGION`.

> **Security tip:** Never put credentials (`credentials = file("key.json")`)
> into code that gets committed. Use ADC locally and Workload Identity
> Federation in CI.

The provider block is optional if all settings come from the environment, but
being explicit makes code easier to understand.

## 4.6 Multiple configurations of one provider: aliases `[2c]`

Sometimes you need the same provider with **different settings** — for
example, resources in two regions, or two different projects. Use the
`alias` meta-argument:

```hcl
# Default configuration (no alias)
provider "google" {
  project = "tf-book-fatih-12345"
  region  = "europe-west1"
}

# Additional configuration
provider "google" {
  alias   = "us"
  project = "tf-book-fatih-12345"
  region  = "us-central1"
}
```

Resources use the **default** configuration unless you select another with the
`provider` meta-argument, using `<local name>.<alias>`:

```hcl
resource "google_compute_network" "main" {
  name                    = "main"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "europe" {
  name          = "europe"
  ip_cidr_range = "10.0.0.0/24"
  network       = google_compute_network.main.id
  # uses the default provider -> europe-west1
}

resource "google_compute_subnetwork" "us" {
  provider      = google.us
  name          = "us"
  ip_cidr_range = "10.1.0.0/24"
  network       = google_compute_network.main.id
  # uses the aliased provider -> us-central1
}
```

Note that `provider = google.us` is a reference, not a string — no quotes.

> **Exam tip:** A provider block *without* `alias` is the default
> configuration. You may have only one default per provider. Resources select
> an alias with `provider = <name>.<alias>`.

## 4.7 Multiple providers in one configuration `[2c]`

A configuration can use any number of different providers. Two very common
companions are `google-beta` and `random`.

### `google-beta` alongside `google`

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "8.9.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "8.9.0"
    }
  }
}

provider "google" {
  project = "tf-book-fatih-12345"
  region  = "europe-west1"
}

provider "google-beta" {
  project = "tf-book-fatih-12345"
  region  = "europe-west1"
}

# A resource can explicitly use google-beta when it needs a beta feature.
resource "google_compute_network" "beta_net" {
  provider                = google-beta
  name                    = "beta-net"
  auto_create_subnetworks = false
}
```

Resource types start with `google_` in both variants, so you must choose
`google-beta` explicitly with `provider = google-beta`. Keep `google` and
`google-beta` on the **same version** to avoid surprises.

### The `random` provider

Some providers don't talk to any cloud at all. `hashicorp/random` generates
random values that stay stable once created (they're stored in state):

```hcl
resource "random_id" "suffix" {
  byte_length = 4
}

resource "google_storage_bucket" "data" {
  name     = "data-${random_id.suffix.hex}" # e.g. data-8f3a1c2b
  location = "EU"
}
```

This solves the globally-unique bucket name problem neatly. Other utility
providers include `hashicorp/time`, `hashicorp/tls`, `hashicorp/local`,
`hashicorp/http`, and `hashicorp/archive`.

The `"data-${...}"` syntax is **string interpolation**: the expression between
`${` and `}` is evaluated and inserted into the string. You will see much more
of it in Chapter 7.

## 4.8 How Terraform picks a provider for each resource

1. If the resource has a `provider` argument, use that configuration.
2. Otherwise take the resource type's prefix (`google_storage_bucket` →
   `google`) and use that provider's **default** configuration.
3. The local name maps to a source address via `required_providers`.

## Common mistakes and exam tips

* **Forgetting `terraform init` after adding a provider** — "Required plugins
  are not installed".
* **Expecting `init` to upgrade providers** — it uses the lock file; you
  need `init -upgrade`.
* **Quoting the provider reference** — `provider = "google.us"` is wrong;
  write `provider = google.us`.
* **Mismatched `google` and `google-beta` versions** — keep them identical.
* Providers are versioned separately from Terraform.
* The lock file pins **providers only**, not modules.

## Summary

* Providers are plugins that implement resources and data sources and talk to
  APIs. They are downloaded from the Terraform Registry by `init`.
* Declare providers in `required_providers` with a `source` and a `version`
  constraint; know the constraint operators, especially `~>`.
* The lock file records exact versions and checksums; commit it and use
  `init -upgrade` to move forward deliberately.
* The `provider` block configures defaults; `alias` creates additional
  configurations selected with the `provider` meta-argument.
* One configuration can mix many providers.

## Quick check

1. What versions does `version = "~> 8.9"` allow? And `"~> 8.9.0"`?
2. A teammate changed the constraint from `"8.9.0"` to `"~> 8.9"` and ran
   `terraform init`. Which version is used, and why?
3. How do you make a resource use a non-default provider configuration?
4. What is the full source address of the Google provider?
5. Name two things recorded in `.terraform.lock.hcl`.

---

## Hands-on exercise: Buckets in two regions with random names

**Goal:** Use three providers (`google`, `google-beta`, `random`) and a
provider alias in one configuration.

**Estimated time:** 25 minutes

**Files:** `code/ch04-providers/exercise/`

### Steps

1. `cd code/ch04-providers/exercise` and open `versions.tf`. Complete the
   `TODO`s to require `hashicorp/google` 8.9.0, `hashicorp/google-beta` 8.9.0,
   and `hashicorp/random` 3.9.1.
2. In `providers.tf`, set your project ID. Add a **second** `google` provider
   configuration with `alias = "us"` and `region = "us-central1"`. Configure
   `google-beta` too.
3. In `main.tf`:
   * Create a `random_id` resource named `suffix` with `byte_length = 4`.
   * Create a bucket `eu` in location `EUROPE-WEST1` using the default
     provider, named `ch04-eu-<suffix>`.
   * Create a bucket `us` in location `US-CENTRAL1` using the `google.us`
     provider, named `ch04-us-<suffix>`.
   * Create a third bucket `beta` that uses the `google-beta` provider.
4. Run `terraform init`. Open `.terraform.lock.hcl` and find all three providers.
5. Run `terraform providers` and `terraform version`.
6. Run `terraform plan` and `terraform apply`.
7. Run `gcloud storage buckets list --format="table(name,location)"` and
   confirm the locations.
8. Change the `random` version constraint to `"~> 3.9"` and run
   `terraform init`. Was a different version installed? Now try
   `terraform init -upgrade`. Change it back to `"3.9.1"` afterwards and run
   `terraform init -upgrade` again.

### Expected result

Three buckets sharing the same random suffix, two in Europe and one in the US.

### Stretch goal

Add checksums for macOS and Windows to the lock file with
`terraform providers lock -platform=...`. How did the file change?

### Cleanup

```console
$ terraform destroy
```

---

## Quick check answers

1. `~> 8.9` allows `>= 8.9, < 9.0`; `~> 8.9.0` allows `>= 8.9.0, < 8.10.0`.
2. Still 8.9.0, because `init` reuses the version recorded in the lock file
   as long as it satisfies the constraint. Use `init -upgrade` to move to a
   newer one.
3. Set the `provider` meta-argument, e.g. `provider = google.us`.
4. `registry.terraform.io/hashicorp/google`.
5. The selected version, the constraints, and the package checksums
   (hashes).
