# Review — Part III: State

*About 15 minutes. Chapters 9–11, with three questions from earlier Parts.*

Answer each question aloud or in writing **before** you look at the answers.
The questions mix chapters on purpose, and from Part II on they reach back to
earlier Parts: recalling something after a gap is what makes it stick. Mark
every question you couldn't answer and reread the section named in its answer.

## Questions

1. Give three reasons why Terraform needs state. What happens if the state
   file is deleted while the resources still exist?
2. What in the state makes it sensitive? Name three ways to protect it.
3. Two people run `terraform apply` at the same moment. What happens if each
   uses the local backend on their own laptop? What happens with a shared
   `gcs` backend?
4. List the steps for moving a configuration from local state to a GCS bucket.
   What should the next plan show, and what do you do with the old file?
5. Why can't a `backend` block use variables, and what do you use instead?
6. Configuration B needs a value that a module inside configuration A
   produces. Describe the whole chain.
7. For each task, name the declarative way and the older command: rename a
   resource; stop managing an object but keep it; adopt an existing object;
   re-create a broken object; accept a manual change into state.
8. *From Part II:* You change a resource from `count` to `for_each`. Why does
   Terraform want to destroy and re-create the instances, and how do you
   prevent it?
9. *From Part II:* What is the difference in behaviour between a failing
   `precondition` and a failing `check` block?
10. *From Part I:* After which kinds of change must you run `terraform init`
   again?

## From memory

Take any small configuration you have applied. Without the book: rename a
resource with a `moved` block and confirm the plan shows no destroy; inspect
it with `terraform state list` and `terraform state show`; change a label with
`gcloud` and find the drift with a refresh-only plan. Destroy afterwards.

## Answers

1. It maps configuration to real objects, keeps metadata such as dependencies,
   and caches attributes (plus: a shared record for teams). Without it
   Terraform knows of no resources and plans to create everything again; you
   restore a backup or import. Section 9.1.
2. Every attribute is stored in plain text, including passwords and keys. Keep
   it out of Git; use a remote backend with encryption and tight IAM; enable
   versioning; prefer ephemeral values. Sections 9.2 and 10.2.
3. Local: two unrelated state files, no common lock, duplicate or conflicting
   resources. GCS: the first run takes the lock; the second waits
   (`-lock-timeout`) or fails with a lock error. Sections 9.3–9.4 and 10.1.
4. Add the `backend "gcs"` block, run `terraform init` (or `init
   -migrate-state`), answer yes to copying. The plan must show no changes.
   Then delete the local state file. Section 10.4.
5. The backend is set up during `init`, before variables are evaluated. Use
   partial configuration: leave values out and pass them with
   `-backend-config`. Sections 10.3 and 10.5.
6. The module declares an output; A's root module re-exports it as a root
   output and is applied; B reads it with `terraform_remote_state` as
   `.outputs.<name>`. Section 10.6.
7. `moved` / `state mv`; `removed` with `destroy = false` / `state rm`;
   `import` block / `terraform import`; `-replace` / `taint`; `apply
   -refresh-only` / `refresh`. Section 11.8.
8. The addresses change from `x[0]` to `x["key"]`, and Terraform identifies
   objects by address. Add `moved` blocks from the old to the new addresses.
   Sections 7.8 and 11.6.
9. A precondition stops the plan or apply with an error; a check block prints
   a warning and lets it continue. Sections 8.3–8.4.
10. After adding or changing a provider, a module, a version constraint, or
   the backend. Sections 3.3 and 10.4.
