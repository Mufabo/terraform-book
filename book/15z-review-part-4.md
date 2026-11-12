# Review — Part IV: Modules and Security

*About 15 minutes. Chapters 12–15, with two questions from earlier Parts.*

Answer each question aloud or in writing **before** you look at the answers.
The questions mix chapters on purpose, and from Part II on they reach back to
earlier Parts: recalling something after a gap is what makes it stick. Mark
every question you couldn't answer and reread the section named in its answer.

## Questions

1. Name four kinds of module source. How is each pinned to a version, and does
   the lock file help?
2. A child module needs the project ID and returns a bucket URL that a second
   module needs. Describe the wiring. What can't the child module see?
3. Why does a reusable module contain no `provider` block? How do the version
   constraints of a root module and a reusable module differ?
4. You move an existing resource into a module. What happens without further
   action, and what do you add?
5. List the places where a secret can leak in a Terraform workflow. Which of
   them does `sensitive = true` close?
6. Compare three ways for Terraform to handle a secret: an ordinary data
   source, an ephemeral resource, and a write-only argument. What is the
   `_wo_version` argument for?
7. Classify each error and name the first tool you'd use: (a) "Unsupported
   argument"; (b) "Error acquiring the state lock"; (c) "Error 403: Required
   ... permission"; (d) "Cycle".
8. What do `TF_LOG`, `TF_LOG_PATH`, `TF_LOG_CORE`, and `TF_LOG_PROVIDER` do?
   Why shouldn't logging be on all the time?
9. *From Part III:* What is the difference between running `terraform state
   rm` for a resource and deleting its block from the configuration?
10. *From Part II:* A module is called with `for_each`. How do you refer to an
   output of one instance, and to the same output of all instances?

## From memory

Without the book, write a tiny module (one bucket, one validated input
variable, one output) with a `versions.tf` fit for a reusable module. Call it
twice from a root module with `for_each`. `terraform validate` is enough.

## Answers

1. Local path (no version), registry and private registry (`version`
   argument), Git or GitHub (`?ref=` in the source), archives over HTTP or
   from buckets (no version). The lock file covers providers only. Sections
   12.3–12.4.
2. The root passes the project ID as an input variable; the child declares an
   output; the root passes `module.a.url` into an input of the second module.
   The child sees none of the parent's variables, locals, or resources.
   Section 13.3.
3. The caller configures providers and the module inherits them; a provider
   block inside would take that control away (and block `count` and `for_each`
   on the module). Root modules pin exactly or tightly; modules give a
   minimum, perhaps with an upper bound. Sections 13.2 and 4.3.
4. The address changes to `module.<name>.<type>.<name>`, so Terraform would
   destroy and re-create the object. A `moved` block from the old to the new
   address prevents that. Section 13.5.
5. Code, tfvars files, CLI output and CI logs, saved plan files, state, and
   debug logs. `sensitive` closes only the CLI output. Sections 14.1–14.2.
6. A data source's result is stored in state. An ephemeral resource's result
   exists only during the run. A write-only argument sends a value to the API
   without storing it. Because Terraform can't compare what it doesn't store,
   you raise the version number to send a new value. Section 14.3.
7. (a) Language: `validate` and the provider docs. (b) State: wait, or
   `force-unlock` if the lock is stale. (c) Provider: check the identity and
   its roles, then a debug log. (d) Core: read the addresses in the message
   and break one reference. Sections 15.1 and 15.5–15.6.
8. `TF_LOG` turns logging on at a level; `TF_LOG_PATH` sends it to a file (it
   needs a level too); the other two limit logging to Core or to providers.
   Logs are huge, slow things down, and can contain secrets and tokens.
   Section 15.3.
9. `state rm` makes Terraform forget the object, which keeps running. Deleting
   the block makes the next apply destroy it. Sections 9.6 and 11.7.
10. `module.<name>["key"].<output>`, and `{ for k, m in module.<name> : k =>
   m.<output> }`. Sections 7.7 and 12.2.
