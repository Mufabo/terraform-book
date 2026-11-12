# Review — Part I: Foundations

*About 15 minutes. Chapters 1–4.*

Answer each question aloud or in writing **before** you look at the answers.
The questions mix chapters on purpose, and from Part II on they reach back to
earlier Parts: recalling something after a gap is what makes it stick. Mark
every question you couldn't answer and reread the section named in its answer.

## Questions

1. You clone a repository that contains `.tf` files and a lock file, but no
   `.terraform` folder. List the commands from the clone to the created
   resources, in order, and say which of them contact Google Cloud.
2. A colleague says: "The plan was clean, so the apply can't fail." Give two
   reasons why that is wrong.
3. `terraform fmt -check`, `terraform validate`, and `terraform plan` each
   catch a different kind of mistake. Give one example for each that the one
   before it can't catch.
4. A configuration requires the Google provider `~> 8.9`, and the lock file
   records 8.9.0. Describe exactly how you move to 8.10.0, and what you
   commit.
5. Why is `.terraform.lock.hcl` committed to Git, while `.terraform/` and
   `terraform.tfstate` are not?
6. You apply a configuration twice; the second apply reports no changes. Then
   someone deletes the bucket in the console, and you apply a third time. What
   happens, and which property of Terraform does this show?
7. One configuration needs resources in `europe-west1` and in `us-central1`,
   plus a random name suffix. Which blocks do you need, and how does a
   resource choose its provider configuration?
8. In a plan, what do `+`, `~`, `-/+`, and `(known after apply)` mean? Which
   of them should make you stop and read carefully?

## From memory

In a new, empty folder and **without looking anything up**, write the three
files for one Cloud Storage bucket with a label. Take it through `init`,
`fmt`, `validate`, a saved plan, `apply`, and `destroy`. Afterwards, compare
with section 3.2 and note what you had to guess.

## Answers

1. `init` (downloads providers from the registry; no Google Cloud call),
   optionally `fmt -check` and `validate` (both local), `plan` (reads from
   Google Cloud), `apply` (changes it). Section 3.9.
2. A plan is a prediction. The apply can still fail on a missing permission,
   an exhausted quota, a name that is already taken, or an API that isn't
   enabled. Section 1.4.
3. `fmt -check`: wrong indentation. `validate`: a misspelt argument or a
   reference to something that doesn't exist. `plan`: anything that needs the
   real world, such as a resource that would be replaced. Sections 3.4–3.6.
4. `terraform init -upgrade`, read the provider's changelog, `terraform plan`,
   then commit the changed `.terraform.lock.hcl`. Plain `init` would stay on
   8.9.0. Section 4.4.
5. The lock file makes everyone use the same provider builds. `.terraform/` is
   downloaded content that `init` re-creates. State can contain secrets and
   doesn't belong in Git. Section 3.3.
6. Terraform reads the real world, sees that the bucket is missing, and
   creates it again. It always works towards the declared state (declarative,
   idempotent). Sections 1.3 and 3.7.
7. Two entries in `required_providers` (`google`, `random`); a default
   `provider "google"` block and a second one with `alias`; resources select
   the alias with `provider = google.<alias>`, otherwise they use the default.
   Sections 4.6–4.8.
8. Create; update in place; destroy and re-create; a value that only exists
   once the resource does. `-/+` (and any unexpected `-`) can mean data loss.
   Section 3.6.
