# Chapter 7 — Expressions and Functions

## Learning objectives

By the end of this lesson you will be able to:

* Use operators, conditional expressions, and string templates. `[4e]`
* Transform collections with `for` expressions and splat expressions. `[4e]`
* Create multiple resource instances with `count` and `for_each`, and choose
  between them. `[4e]`
* Generate repeated nested blocks with `dynamic` blocks. `[4e]`
* Use common built-in functions and experiment in `terraform console`. `[4e]`

**Time:** about 50 minutes — 20 reading, 5 quick check, 25 exercise.

---

## 7.1 Expressions

An **expression** is anything that produces a value: `"EU"`, `var.region`,
`google_compute_network.main.id`, `2 + 2`. You've been using expressions
since Chapter 3. This chapter adds the tools that make configuration
*dynamic*.

### Your laboratory: `terraform console`

`terraform console` opens an interactive prompt where you can evaluate
expressions. It loads your variables and current state, so you can test
references too:

```console
$ terraform console
> 1 + 2
3
> upper("europe-west1")
"EUROPE-WEST1"
> var.region
"europe-west1"
> exit
```

Keep a console open while you read this chapter and try every example.

## 7.2 Operators and conditionals

| Kind | Operators |
|---|---|
| Arithmetic | `+ - * / %` |
| Comparison | `== != < <= > >=` |
| Logical | `&& \|\| !` |

The **conditional expression** chooses between two values:

```
condition ? value_if_true : value_if_false
```

```hcl
machine_type = var.environment == "prod" ? "e2-standard-2" : "e2-micro"
```

Both results should have the same type.

## 7.3 String templates

**Interpolation** inserts a value into a string:

```hcl
name = "${var.environment}-web-${random_id.suffix.hex}"
```

**Directives** add logic inside strings with `%{ ... }`:

```hcl
locals {
  greeting = "Hello, %{if var.name != ""}${var.name}%{else}stranger%{endif}!"

  hosts_file = <<EOT
%{for name, ip in var.hosts~}
${ip} ${name}
%{endfor~}
EOT
}
```

The `~` strips whitespace and newlines next to the directive, so
`hosts_file` becomes one `IP name` line per host. Write such templates with
`<<EOT` and no indentation: with the indented `<<-EOT` form, the `~` markers
also keep the indentation from being removed, and every line would start
with spaces. For anything complex, the `templatefile()` function (7.9) is
clearer.

## 7.4 `for` expressions

A `for` expression transforms one collection into another — like a list
comprehension in Python.

**Produce a list** with square brackets:

```hcl
> [for z in ["b", "c", "d"] : "europe-west1-${z}"]
[
  "europe-west1-b",
  "europe-west1-c",
  "europe-west1-d",
]
```

**Produce a map** with curly braces and `=>`:

```hcl
> { for name in ["logs", "backups"] : name => upper(name) }
{
  "backups" = "BACKUPS"
  "logs" = "LOGS"
}
```

**Filter** with `if`:

```hcl
> [for p in [22, 80, 443, 3306] : p if p != 22]
[
  80,
  443,
  3306,
]
```

**Iterate over a map** with two symbols (key and value):

```hcl
[for name, cfg in var.buckets : "${name} is in ${cfg.location}"]
```

**Group** results when keys repeat, with `...`:

```hcl
{ for b in var.bucket_list : b.location => b.name... }
# { "EU" = ["a", "c"], "US" = ["b"] }
```

## 7.5 Splat expressions

A **splat** `[*]` is a shortcut for a simple `for` that extracts one
attribute from every element of a list:

```hcl
var.users[*].email
# same as
[for u in var.users : u.email]
```

You'll often use it with `count` resources:
`google_compute_instance.web[*].name`.

## 7.6 Multiple instances: `count`

So far each resource block created exactly one object. The `count`
meta-argument creates **several instances** of the same resource:

```hcl
resource "google_compute_instance" "web" {
  count        = 3
  name         = "web-${count.index}" # web-0, web-1, web-2
  machine_type = "e2-micro"
  zone         = "europe-west1-b"
  # ...
}
```

* `count.index` is the instance number, starting at 0.
* Instances are addressed with an index: `google_compute_instance.web[0]`.
* The whole resource is a list: `google_compute_instance.web[*].self_link`.

### Conditional creation

`count` is the idiomatic way to create a resource **only if** a condition is
true:

```hcl
resource "google_compute_firewall" "ssh" {
  count = var.enable_ssh ? 1 : 0
  # ...
}
```

Refer to it carefully, because it may have zero instances:
`one(google_compute_firewall.ssh[*].name)` returns the name or `null`.

### The problem with `count` and lists

Suppose `count = length(var.zones)` with `zones = ["b", "c", "d"]`. If you
remove `"b"` from the front of the list, every remaining element shifts
index: `c` moves from `[1]` to `[0]`. Terraform sees *changes to every
instance* and may destroy and re-create them. That's why `for_each` exists.

## 7.7 Multiple instances: `for_each`

`for_each` creates one instance per element of a **map** or a **set of
strings**, identified by **key** instead of index:

```hcl
variable "buckets" {
  type = map(object({
    location      = string
    storage_class = optional(string, "STANDARD")
  }))
  default = {
    logs    = { location = "EU" }
    backups = { location = "EU", storage_class = "NEARLINE" }
  }
}

resource "google_storage_bucket" "this" {
  for_each = var.buckets

  name                        = "${var.project_id}-${each.key}"
  location                    = each.value.location
  storage_class               = each.value.storage_class
  uniform_bucket_level_access = true
}
```

* `each.key` — the map key (`"logs"`) or the set element.
* `each.value` — the map value (the object) or, for sets, the same as
  `each.key`.
* Instances are addressed by key: `google_storage_bucket.this["logs"]`.
* The whole resource is a **map**:
  `{ for k, b in google_storage_bucket.this : k => b.url }`.

Removing `logs` from the map destroys exactly that bucket; `backups` is
untouched.

With a list, convert to a set first: `for_each = toset(var.zone_names)`.

### `count` or `for_each`?

| Use | When |
|---|---|
| `count` | Instances are identical, or for on/off (`0` or `1`). |
| `for_each` | Instances differ, or you might add/remove items in the middle. **Default choice.** |

Restrictions: you can't use both on one resource, and the keys/length must be
known at **plan time** — you can't use `for_each` over values that are only
"known after apply", such as IDs of resources that don't exist yet.

> **Exam tip:** `count.index` vs `each.key`/`each.value`; resources with
> `count` are lists, resources with `for_each` are maps. `for_each` accepts a
> map or a **set of strings**, not a list.

## 7.8 `dynamic` blocks

`count` and `for_each` repeat *resources*. What about repeating a **nested
block** inside a resource, such as multiple `allow` blocks in a firewall
rule? Use a `dynamic` block:

```hcl
variable "rules" {
  type = list(object({
    protocol = string
    ports    = list(string)
  }))
  default = [
    { protocol = "tcp", ports = ["80", "443"] },
    { protocol = "icmp", ports = [] },
  ]
}

resource "google_compute_firewall" "web" {
  name    = "web"
  network = google_compute_network.main.id

  dynamic "allow" {
    for_each = var.rules
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }

  source_ranges = ["0.0.0.0/0"]
}
```

* The label (`"allow"`) is the name of the nested block to generate.
* Inside `content`, the iterator is named after the block: `allow.key`,
  `allow.value`. Rename it with `iterator = rule` if you like.

Use dynamic blocks sparingly: they make code harder to read. If the blocks are
fixed, just write them out.

## 7.9 Built-in functions

Terraform has around 120 built-in functions. You **can't** write your own
functions in HCL (although providers can ship functions, called like
`provider::google::region_from_zone("europe-west1-b")`). Function calls look
like `name(arg1, arg2)`.

The most useful ones, by category:

**String**

| Function | Example | Result |
|---|---|---|
| `lower`, `upper` | `lower("EU")` | `"eu"` |
| `format` | `format("vm-%03d", 7)` | `"vm-007"` |
| `join`, `split` | `join(",", ["a","b"])` | `"a,b"` |
| `replace` | `replace("a_b", "_", "-")` | `"a-b"` |
| `substr` | `substr("europe-west1", 0, 6)` | `"europe"` |
| `trimspace`, `trimprefix`, `trimsuffix` | `trimsuffix("a.txt", ".txt")` | `"a"` |
| `startswith`, `endswith`, `strcontains` | `startswith("prod-db", "prod")` | `true` |
| `regex`, `regexall` | `regex("[0-9]+", "web42")` | `"42"` |

**Collection**

| Function | Example | Result |
|---|---|---|
| `length` | `length(["a","b"])` | `2` |
| `concat` | `concat(["a"], ["b"])` | `["a","b"]` |
| `merge` | `merge({a=1}, {b=2})` | `{a=1, b=2}` |
| `lookup` | `lookup(var.sizes, "prod", "e2-micro")` | value or default |
| `contains` | `contains(["a","b"], "a")` | `true` |
| `keys`, `values` | `keys({a=1,b=2})` | `["a","b"]` |
| `flatten` | `flatten([["a"],["b","c"]])` | `["a","b","c"]` |
| `distinct`, `sort`, `reverse` | `distinct(["a","a"])` | `["a"]` |
| `element` | `element(["a","b"], 3)` | `"b"` (wraps around) |
| `zipmap` | `zipmap(["a","b"], [1,2])` | `{a=1,b=2}` |
| `one` | `one(["x"])` | `"x"` (or `null` for `[]`) |
| `slice` | `slice(["a","b","c"], 0, 2)` | `["a","b"]` |
| `setunion`, `setintersection`, `setsubtract` | | set operations |

**Numeric**: `min`, `max`, `ceil`, `floor`, `abs`, `parseint`.

**Type conversion**: `tostring`, `tonumber`, `tobool`, `tolist`, `toset`,
`tomap`.

**Encoding**: `jsonencode`, `jsondecode`, `yamlencode`, `yamldecode`,
`base64encode`, `base64decode`, `urlencode`.

**Filesystem**: `file("script.sh")`, `fileexists`, `templatefile`,
`fileset`. Use `path.module` to build paths relative to the current module:
`file("${path.module}/scripts/startup.sh")`.

**IP network**: `cidrsubnet`, `cidrhost`, `cidrnetmask`.

```hcl
> cidrsubnet("10.0.0.0/16", 8, 1)
"10.0.1.0/24"
> cidrhost("10.0.1.0/24", 5)
"10.0.1.5"
```

`cidrsubnet(prefix, newbits, netnum)` adds `newbits` to the prefix length and
picks subnet number `netnum`. Great for carving subnets out of a range.

**Error handling**: `try(expr, fallback)` returns the first expression that
doesn't error; `can(expr)` returns `true`/`false`; `coalesce(a, b, ...)`
returns the first non-null, non-empty value.

```hcl
> try(var.settings.timeout, 30)
30
```

**Date/time and hashing**: `timestamp()`, `formatdate`, `uuid()`, `sha256`,
`md5`. Be careful: `timestamp()` and `uuid()` return a new value on every
run, causing a change in every plan.

### `templatefile`

`templatefile(path, vars)` renders a file using the same template syntax as
strings. It keeps long scripts out of your `.tf` files.

`scripts/startup.sh.tftpl`:

```bash
#!/bin/bash
apt-get update && apt-get install -y nginx
cat > /var/www/html/index.html <<HTML
<h1>${title}</h1>
<ul>
%{ for item in items ~}
  <li>${item}</li>
%{ endfor ~}
</ul>
HTML
```

```hcl
metadata_startup_script = templatefile("${path.module}/scripts/startup.sh.tftpl", {
  title = "Hello from ${var.environment}"
  items = ["one", "two"]
})
```

## 7.10 Putting it together

```hcl
variable "subnets" {
  type = map(object({
    region = string
  }))
  default = {
    europe = { region = "europe-west1" }
    us     = { region = "us-central1" }
  }
}

locals {
  # Give each subnet a /24 from 10.0.0.0/16, in a stable order.
  subnet_names = sort(keys(var.subnets))
  subnet_cidrs = {
    for i, name in local.subnet_names : name => cidrsubnet("10.0.0.0/16", 8, i)
  }
}

resource "google_compute_subnetwork" "this" {
  for_each = var.subnets

  name          = "${var.environment}-${each.key}"
  region        = each.value.region
  ip_cidr_range = local.subnet_cidrs[each.key]
  network       = google_compute_network.main.id
}

output "subnet_ranges" {
  value = { for k, s in google_compute_subnetwork.this : k => s.ip_cidr_range }
}
```

Note `for i, name in <list>`: when iterating a list with two symbols, the first
is the index.

## Common mistakes and exam tips

* Using `for_each` with a list → error. Use `toset()` or a map.
* Using values known only after apply in `for_each` keys or `count`.
* Removing an item from the middle of a `count` list → many unexpected
  changes. Prefer `for_each`.
* Forgetting that `count`/`for_each` change how you reference the resource:
  `x[0]` vs `x["key"]`.
* `timestamp()` / `uuid()` in arguments cause perpetual diffs.
* You cannot define your own functions in HCL.

## Summary

* Conditionals (`? :`), templates, `for`, and splat expressions build values
  dynamically.
* `count` creates N indexed instances (and on/off resources); `for_each`
  creates keyed instances from a map or set — prefer `for_each`.
* `dynamic` blocks repeat nested blocks.
* Built-in functions cover strings, collections, encoding, files, networks,
  and error handling. Test them in `terraform console`.

## Quick check

1. Write a `for` expression that turns `["a", "b"]` into `{ a = "A", b = "B" }`.
2. How do you reference the `url` of the instance with key `"logs"` of
   `google_storage_bucket.this` (which uses `for_each`)?
3. What does `cidrsubnet("10.1.0.0/16", 4, 2)` return?
4. When is `count` a better choice than `for_each`?
5. What does `try(var.config.port, 8080)` do?

**Scenario questions** (exam style; one answer each)

6. A resource uses `count = length(var.names)` with `names = ["a", "b", "c"]`.
   You remove `"a"` from the list. What does the plan show?

   * A. Only the instance for `a` is destroyed.
   * B. No changes.
   * C. The instances at indexes 0 and 1 are changed or replaced and index 2
     is destroyed, because every remaining element moved to a new index.
   * D. An error, because the list got shorter.

7. In a new configuration, `for_each = toset([for s in
   google_compute_subnetwork.this : s.id])` fails with "Invalid for_each
   argument". Why?

   * A. The keys come from values that are only known after apply; `for_each`
     keys must be known at plan time.
   * B. `for_each` doesn't accept sets.
   * C. `toset()` can't be used with a `for` expression.
   * D. The subnets need `count` first.

---

## Hands-on exercise: A dynamic multi-region network

**Goal:** Use `for_each`, `count`, `dynamic` blocks, `for` expressions, and
functions to build a network driven entirely by variables.

**Estimated time:** 25 minutes

**Files:** `code/ch07-expressions/exercise/`

### Steps

1. `cd code/ch07-expressions/exercise`. Copy `terraform.tfvars.example` to
   `terraform.tfvars` and set your project ID.
2. Open `terraform console` and evaluate the expressions listed in
   `console-practice.md`. Predict each result before pressing Enter.
3. In `main.tf`, complete the `TODO`s:
   * `locals.subnet_cidrs`: a map from subnet name to
     `cidrsubnet(var.base_cidr, 8, <index>)`.
   * `google_compute_subnetwork.this` with `for_each = var.subnets`.
   * `google_compute_firewall.ingress` with a `dynamic "allow"` block over
     `var.firewall_rules`.
   * `google_compute_firewall.ssh` created only when `var.enable_ssh` is
     `true` (use `count`).
   * `google_storage_bucket.this` with `for_each` over `var.buckets`.
4. In `outputs.tf`, output a map of subnet name → CIDR and a list of bucket
   URLs (use a `for` expression or `values()`).
5. Run `terraform init`, `plan`, and `apply`.
6. Add a third subnet `us-east = { region = "us-east1" }` to
   `terraform.tfvars`. Plan: only one subnet is added, and nothing else
   changes. Apply. (The name matters: `subnet_cidrs` numbers the subnets in
   alphabetical order, and `us-east` sorts after `europe` and `us`. A name
   that sorts earlier, such as `asia`, would shift the CIDRs of the existing
   subnets and force their replacement. The stretch goal explores this.)
7. Set `enable_ssh = true`, plan, and note the address
   `google_compute_firewall.ssh[0]`.

### Expected result

Two (then three) subnets in different regions with non-overlapping /24
ranges, one firewall rule with several `allow` blocks, and buckets created
from a map.

### Stretch goal

Remove `europe` from `var.subnets` and plan. Thanks to `for_each`, only
that subnet should be destroyed. But because `subnet_cidrs` is derived from
the sorted *list* of names, the CIDRs of the others may shift — would that
force replacement? How could you make the CIDR assignment stable? (Hint: put
an explicit `index` or `cidr` in each subnet object.)

### Challenge

*Optional, about 30 minutes. There are no starter files and no `TODO`s: work
in a new, empty folder from the requirements alone. A reference solution is in
`code/ch07-expressions/challenge/`.*

Several teams each need a bucket in some environments. The input is:

```hcl
teams = {
  shop    = { environments = ["dev", "prod"] }
  reports = { environments = ["prod"], location = "EUROPE-WEST1" }
}
```

* Declare the variable with a precise type; `location` is optional and
  defaults to `EU`.
* Create **one bucket per team and environment** (three for the input above),
  named `<project>-<team>-<environment>`, with `team` and `environment`
  labels. One resource block, `for_each`, keys such as `shop-dev`. You'll
  need to turn the nested input into a flat map first; `flatten()` helps.
* Buckets that are **not** `prod` get a lifecycle rule that deletes objects
  after `var.temporary_days` (default 14). Prod buckets get no rule.
* Outputs: the bucket names grouped by team
  (`{ reports = [...], shop = [...] }`), and a list with the URLs of the prod
  buckets only.

Work out the expressions in `terraform console` first.

**Done when** the plan shows three buckets, only `shop-dev` has a lifecycle
rule, and adding a team to the variable adds buckets without touching the
existing ones.

### Cleanup

```console
$ terraform destroy
```

---

## Quick check answers

1. `{ for s in ["a", "b"] : s => upper(s) }`
2. `google_storage_bucket.this["logs"].url`
3. `"10.1.32.0/20"`
4. When instances are identical/interchangeable, or to create a resource
   conditionally (`count = var.enabled ? 1 : 0`).
5. Returns `var.config.port` if it can be evaluated without error, otherwise
   `8080`.
6. **C.** `count` identifies instances by position. `for_each` identifies them
   by key and would remove only `a`.
7. **A.** Use keys that are known during planning, such as the keys of the
   subnet map.
