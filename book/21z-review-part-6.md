# Review — Part VI: Real-World Operations

*About 15 minutes. Chapters 18–21, with two questions from earlier Parts.*

Answer each question aloud or in writing **before** you look at the answers.
The questions mix chapters on purpose, and from Part II on they reach back to
earlier Parts: recalling something after a gap is what makes it stick. Mark
every question you couldn't answer and reread the section named in its answer.

## Questions

1. Compare the three strategies for environments (CLI workspaces, tfvars per
   environment, directory per environment) on state isolation, on whether the
   code shows which environment you're in, and on gradual promotion.
2. Why is a separate Google Cloud project per environment the strongest
   boundary? Name three things to keep separate per environment.
3. Name the levels of the testing pyramid with one tool each. Which levels
   need a cloud?
4. What do tests with a mock provider prove, and what don't they? When do you
   need `command = apply`, and what is `expect_failures` for?
5. In a policy library, what is a template and what is a constraint? When do
   you choose a CAI-based constraint? What do the exit codes 0 and 2 of `vet`
   mean?
6. Why do policy tools check the plan rather than the `.tf` files?
7. What does the pipeline run on a pull request, and what on a merge to
   `main`? Why does the apply job plan again?
8. Which three identities does the pipeline use? Why are the apply identities
   bound to a GitHub environment, and what does the `attribute_condition` add?
9. *From Part V:* Sentinel in HCP Terraform and `gcloud terraform vet` in your
   own pipeline sit at the same place in the workflow. Where is that, and how
   do the tools differ?
10. *From Parts I and IV:* A pipeline applies a saved plan. What does that
   guarantee? Name two things a pipeline must never print into its log.

## From memory

On paper: add a `staging` environment between dev and prod to the Chapter 21
pipeline. Which files and folders are new, which state prefix does it use,
which identity applies it, where does an approval go, and what changes in the
bootstrap configuration?

## Answers

1. CLI workspaces: one backend, not visible, no. Tfvars per environment:
   separate state possible, partly visible, no. Directory per environment:
   separate, visible, yes with versioned modules. Section 18.4.
2. Each project has its own IAM, quotas, APIs, and billing, so a mistake or a
   stolen identity in dev can't reach prod. Keep separate: state, identities
   (service accounts), and approval rules. Section 18.1.
3. Static (`fmt`, `validate`, TFLint): no. Unit (`terraform test` with plans
   or mocks): no. Integration (`terraform test` with `command = apply`): yes.
   End-to-end (a full environment plus application tests): yes. Section 19.2.
4. They prove your own logic: names, conditionals, loops, validations, wiring.
   They don't prove that the API accepts the configuration. `apply` is needed
   for computed values, which are unknown in a plan. `expect_failures` tests
   that invalid input is rejected. Sections 19.4–19.5.
5. A template is the reusable rule in Rego with its parameters; a constraint
   switches it on with values and a scope. CAI-based constraints are for IAM
   policies including existing grants, and for rules scoped by folder or
   organisation. 0 = no violations, 2 = violations. Sections 20.2–20.5.
6. The plan holds the final values of every change, after variables, modules,
   functions, and defaults have been resolved. Section 20.1.
7. Pull request: `fmt`, TFLint, unit tests, a plan and a policy check per
   environment, and a plan comment. Merge: plan, policy check, and apply for
   dev, then for prod after approval. It plans again because other merges or
   drift may have changed things since the pull request's plan. Sections 21.2
   and 21.5.
8. A read-only plan identity and one apply identity each for dev and prod.
   Only a job in the protected environment gets the `environment` claim, so a
   changed workflow in a pull request can't obtain prod credentials. The
   condition limits the whole pool to tokens from your repository. Section
   21.3.
9. Between plan and apply. Sentinel is built into HCP Terraform, has its own
   language and enforcement levels with overrides. `vet` runs anywhere, uses
   Rego, and can also check Cloud Asset Inventory data and ancestry. Sections
   17.4 and 20.8.
10. What is applied is exactly what was planned, and Terraform refuses the
   plan if the state changed in between. Never print state, sensitive outputs
   (`terraform output -json`), or debug logs with tokens. Sections 3.6, 14.1,
   and 21.5.
