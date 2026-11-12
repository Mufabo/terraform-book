# Chapter 19 challenge: tests for the secure-bucket module

`secure-bucket/` is a copy of the module from Chapter 13, with
`tests/unit.tftest.hcl` added.

```console
$ cd secure-bucket
$ terraform init -backend=false
$ terraform test
...
Success! 8 passed, 0 failed.
```

What the tests pin down, and why each matters:

| Run | Protects against |
|---|---|
| `secure_defaults` | Someone "temporarily" loosening a security setting in the module. |
| `no_lifecycle_rule_by_default`, `retention_creates_delete_rule` | A wrong condition in the `dynamic` block: a rule that always or never appears would delete data or keep it forever. |
| `labels_are_merged` | `merge()` arguments in the wrong order, so a caller could override `managed_by`, or lose their own labels. |
| `one_iam_member_per_reader`, `no_iam_members_without_readers` | Broken `for_each`, or a broader role than `objectViewer`. |
| `rejects_invalid_name` | A validation regex that stopped rejecting anything. |
| `outputs_expose_the_bucket` | An output wired to the wrong attribute. It uses `command = apply`, because outputs built from computed attributes are unknown during `plan`. |

Check that the tests can fail: change `public_access_prevention` to
`"inherited"` in `main.tf`, or swap the arguments of `merge()`, and run
`terraform test` again. A test that can't fail proves nothing.

What these tests don't prove: that Google accepts the configuration. The
mock provider never calls an API.
