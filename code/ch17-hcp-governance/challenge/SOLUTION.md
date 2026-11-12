# Chapter 17 challenge: an organisation's structure as code

> Like the rest of Part V, this solution was validated with
> `terraform validate` but not run against a real organisation. Teams beyond
> the built-in `owners` team need a paid tier.

How the requirements map to `main.tf`:

| Requirement | Resource | Why |
|---|---|---|
| Platform team runs networking | `tfe_team_project_access`, `admin` | One grant on the project covers every workspace in it, including future ones. |
| Developers apply in dev, only plan in prod | Two `tfe_team_access`, `write` and `plan` | Both workspaces are in the same project, so a project grant can't tell them apart. The *Plan* role can queue plans but not apply. |
| Auditors read everything | `tfe_team_project_access`, `read`, per project | Read never exposes sensitive variable values. |
| Only `web-shop-prod` reads `network-prod`'s outputs | `tfe_workspace_settings` with `global_remote_state = false` | Sharing with named workspaces, not the whole organisation. The consumer then uses `tfe_outputs`. |
| `web-shop-prod` re-plans after `network-prod` applies | `tfe_run_trigger` | `workspace_id` is the workspace that gets the new run; `sourceable_id` is the one that triggers it. |

The policy question: "data must stay in the EU" is company-wide and
non-negotiable, so it belongs in a policy set scoped to the whole
organisation at **hard-mandatory**. "Every bucket needs an `owner` label"
has legitimate exceptions, so **soft-mandatory** fits: a lead can override
it for one run, and the override is recorded.

Cleanup: `terraform destroy`.
