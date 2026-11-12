# Chapter 20 challenge: a limit on Cloud Run instances

> This template follows the structure of the chapter's tested templates, but
> it has **not** been run through `gcloud beta terraform vet`. Test it with
> the three cases below before you rely on it.

Copy the two files into your policy library:

```console
$ cp policies/templates/*.yaml   ../exercise/policy-library/policies/templates/
$ cp policies/constraints/*.yaml ../exercise/policy-library/policies/constraints/
```

**How the rule was found.** `terraform show -json tfplan` shows where the
value sits in a resource change:

```json
"after": {
  "template": [
    { "scaling": [ { "max_instance_count": 3, ... } ], ... }
  ]
}
```

Nested blocks are lists in the plan JSON, hence `template[_].scaling[_]`.

**Two rules, not one.** A template may define `violation` more than once;
each body is checked on its own. The first catches a limit that is too high.
The second catches a service with no limit at all: if the block is missing,
the first rule's `configured := ...` line is undefined, the rule doesn't
match, and the service would pass. That is the most common mistake in
"must not exceed" policies.

**Test cases** for the sample's Cloud Run service (`./vet.sh sample policy-library`):

| `scaling` block in `sample/main.tf` | Expected |
|---|---|
| `scaling { max_instance_count = 3 }` | No violation from this constraint |
| `scaling { max_instance_count = 50 }` | "max_instance_count is 50, the limit is 10" |
| No `scaling` block | "scaling.max_instance_count must be set (limit 10)" |

**A stricter limit for one module.** Add a second constraint of the same
kind with another `metadata.name`, `max_instances: 2`, and
`addresses: ["module.batch.**"]`. One template, two constraints.
