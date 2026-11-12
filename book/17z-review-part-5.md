# Review — Part V: HCP Terraform

*About 15 minutes. Chapters 16–17, with two questions from earlier Parts.*

Answer each question aloud or in writing **before** you look at the answers.
The questions mix chapters on purpose, and from Part II on they reach back to
earlier Parts: recalling something after a gap is what makes it stick. Mark
every question you couldn't answer and reread the section named in its answer.

## Questions

1. What belongs at each level in HCP Terraform: organisation, project,
   workspace?
2. How does an HCP Terraform workspace differ from a CLI workspace?
3. Name the three workflows. Which situations produce a speculative plan, and
   what is special about it?
4. You add a `cloud` block to a configuration that has a `gcs` backend with
   existing state. What must you remove, what happens during `init`, and where
   do variable values for remote runs come from?
5. Describe how a run gets Google credentials with dynamic provider
   credentials. Name two things you restrict on the Google side.
6. Name Sentinel's three enforcement levels. Which one can be overridden, and
   at which point of a run are policies checked?
7. Tell these three apart: a run task, a run trigger, a notification.
8. What does a private registry module source look like, and how does a new
   version get published?
9. *From Part IV:* Vault's dynamic secrets and HCP Terraform's dynamic
   provider credentials follow the same idea. What is it?
10. *From Part III:* Compare `terraform_remote_state` and `tfe_outputs`. What
   do they have in common, and what differs?

## From memory

On paper: a company has two applications, each with dev, staging, and prod.
Draw the projects and workspaces, two teams with their permissions, the
variable sets, and where you would attach a company-wide policy set and a
team-specific one. Compare with section 17.8.

## Answers

1. Organisation: teams, the private registry, policies, VCS connections,
   billing. Project: a group of workspaces with shared permissions and
   variable sets. Workspace: one state, its variables, its configuration
   source, settings, and run history. Section 16.2.
2. An HCP Terraform workspace is a full unit with its own state, variables,
   permissions, settings, and history. A CLI workspace is only another state
   file for the same configuration in the same backend. Section 16.2.
3. CLI-driven, VCS-driven, API-driven. Pull requests in the VCS workflow and
   `terraform plan` in the CLI workflow produce speculative plans, which can
   never be applied. Section 16.3.
4. The `backend` block (you can't have both). `init` offers to migrate the
   existing state to the workspace. Values come from workspace variables and
   variable sets (and `*.auto.tfvars`), not from a local `terraform.tfvars`.
   Sections 16.4–16.5.
5. HCP Terraform issues an OIDC token for the run; Google's Workload Identity
   Federation checks it and exchanges it for a short-lived token that
   impersonates a service account. Restrict the provider with an
   `attribute_condition` on your organisation, and bind the service account to
   specific workspaces. Section 16.6.
6. Advisory, soft-mandatory, hard-mandatory. Only soft-mandatory failures can
   be overridden by an authorised user. Policies run after the plan and before
   the apply. Section 17.4.
7. A run task calls an external service at a stage of a run and can block it.
   A run trigger queues a run in one workspace after a successful apply in
   another. A notification only reports run events to a chat tool, email, or
   webhook. Sections 17.2 and 17.5.
8. `app.terraform.io/<organisation>/<name>/<provider>` with a `version`
   argument. With tag-based publishing, each semantic-version Git tag on the
   connected `terraform-<provider>-<name>` repository becomes a version.
   Section 17.3.
9. No long-lived secret is stored anywhere. An identity is verified at run
   time and receives credentials that expire shortly afterwards. Sections
   14.5–14.6 and 16.6.
10. Both expose only the root-module outputs of another configuration.
   `terraform_remote_state` needs read access to the whole state;
   `tfe_outputs` reads the outputs alone. Sections 10.6 and 17.2.
