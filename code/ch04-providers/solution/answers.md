# Chapter 4 — Exercise answers

## Step 5: `terraform providers` vs. `terraform version`

`terraform providers` prints the **constraints** from your configuration;
`terraform version` prints the versions **installed** in `.terraform/`:

```console
$ terraform providers

Providers required by configuration:
.
├── provider[registry.terraform.io/hashicorp/google] 8.9.0
├── provider[registry.terraform.io/hashicorp/google-beta] 8.9.0
└── provider[registry.terraform.io/hashicorp/random] 3.9.1

$ terraform version
Terraform v1.17.0
on linux_amd64
+ provider registry.terraform.io/hashicorp/google v8.9.0
+ provider registry.terraform.io/hashicorp/google-beta v8.9.0
+ provider registry.terraform.io/hashicorp/random v3.9.1
```

With exact pins the two lists look the same. After step 8's change to
`"~> 3.9"`, `terraform providers` shows `~> 3.9` while `terraform version`
still shows `v3.9.1`. (The order of the `terraform providers` lines may
differ.)

## Step 8: loosening and restoring the constraint

* **`terraform init` with `"~> 3.9"`**: no, the version stays 3.9.1. The
  locked version still satisfies the new constraint, so `init` reuses it:

  ```console
  - Reusing version 3.9.1 of hashicorp/random from the dependency lock file
  ```

* **`terraform init -upgrade`**: Terraform ignores the locked version and
  looks for the newest release matching `~> 3.9` (that is, `>= 3.9, < 4.0`).
  At the time of writing, 3.9.1 is the newest `random` release, so nothing
  changes:

  ```console
  - Finding hashicorp/random versions matching "~> 3.9"...
  - Using previously-installed hashicorp/random v3.9.1
  ```

  If a newer 3.x version exists when you try this, `-upgrade` installs it and
  records it in `.terraform.lock.hcl`.

* **Back to `"3.9.1"`, then `terraform init`**: this works as long as the lock
  file still says 3.9.1. If `-upgrade` had moved to a newer version (say
  3.10.0), `init` would fail because the locked version no longer matches the
  constraint:

  ```console
  locked provider registry.terraform.io/hashicorp/random 3.10.0 does not
  match configured version constraint 3.9.1; must use terraform init -upgrade
  to allow selection of new versions
  ```

  Then `terraform init -upgrade` selects 3.9.1 again and rewrites the lock
  file. (Or run `git checkout -- .terraform.lock.hcl` to restore the
  committed lock file.)

## Stretch goal: lock file for several platforms

```console
$ terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64
```

Each provider block gains new `h1:` lines, one per added platform. For three
providers and two new platforms that's six new lines. The `zh:` lines don't
change: they are the registry's SHA-256 sums of the zip files for **all**
platforms and were there from the start. `h1:` hashes cover the unpacked
package, and `init` records one only for the platform it runs on. Recording all
platforms up front means teammates on other systems don't get unexpected
lock file changes, and installs that can only check `h1:` hashes (plugin
cache, local mirror) work for them too.

```diff
 provider "registry.terraform.io/hashicorp/random" {
   version     = "3.9.1"
   constraints = "3.9.1"
   hashes = [
+    "h1:...",
+    "h1:...",
     "h1:g40qr7yDmIpaur4SsK5BcOda3HSo1RJ6zHVMqN4EJ+0=",
     "zh:05f4734c1f0be840b711b3eff259ebc5fca436784c728955b1678078466f48d7",
     ...
```
