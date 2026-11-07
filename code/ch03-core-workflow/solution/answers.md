# Chapter 3 — Exercise answers

## Step 10: update or replacement?

An **in-place update** (`~`). A bucket's default storage class can be changed
on an existing bucket, so the plan shows:

```console
  # google_storage_bucket.notes will be updated in-place
  ~ resource "google_storage_bucket" "notes" {
      ~ storage_class = "STANDARD" -> "NEARLINE"
        ...
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Compare this with `location`, which cannot be changed and so forces
replacement (`-/+`). The change only affects objects uploaded from now on;
`hello.txt` keeps the `STANDARD` class.

## Stretch goal: `-detailed-exitcode`

| Situation | `echo $?` |
|---|---|
| Right after an apply, nothing changed | `0` (no changes) |
| After editing the configuration | `2` (changes present) |
| With an error, e.g. a typo in an argument name | `1` (error) |

A script can branch on the code, for example to run `apply` only when there
are changes, or to raise an alert from a scheduled job that detects drift:

```bash
terraform plan -detailed-exitcode -out=tfplan
case $? in
  0) echo "Nothing to do." ;;
  2) terraform apply tfplan ;;
  *) echo "Plan failed." >&2; exit 1 ;;
esac
```
