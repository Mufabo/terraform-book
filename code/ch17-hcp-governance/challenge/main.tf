provider "tfe" {
  organization = var.organization
}

# --- Structure: one project per area, one workspace per component/env -----

resource "tfe_project" "networking" {
  name = "networking"
}

resource "tfe_project" "web_shop" {
  name = "web-shop"
}

resource "tfe_workspace" "network_prod" {
  name       = "network-prod"
  project_id = tfe_project.networking.id
  tags       = { env = "prod" }
}

resource "tfe_workspace" "web_shop" {
  for_each = toset(["dev", "prod"])

  name       = "web-shop-${each.key}"
  project_id = tfe_project.web_shop.id
  tags       = { env = each.key }
}

# --- Teams: permissions go to teams, never to single users ----------------

resource "tfe_team" "platform" {
  name = "platform"
}

resource "tfe_team" "developers" {
  name = "web-shop-developers"
}

resource "tfe_team" "auditors" {
  name = "auditors"
}

# The platform team runs the networking project.
resource "tfe_team_project_access" "platform_networking" {
  team_id    = tfe_team.platform.id
  project_id = tfe_project.networking.id
  access     = "admin"
}

# Developers may apply in dev but only plan in prod. A project-level grant
# would cover both workspaces, so the grants are per workspace.
resource "tfe_team_access" "developers_dev" {
  team_id      = tfe_team.developers.id
  workspace_id = tfe_workspace.web_shop["dev"].id
  access       = "write"
}

resource "tfe_team_access" "developers_prod" {
  team_id      = tfe_team.developers.id
  workspace_id = tfe_workspace.web_shop["prod"].id
  access       = "plan"
}

# Auditors can read everything in both projects.
resource "tfe_team_project_access" "auditors" {
  for_each = {
    networking = tfe_project.networking.id
    web_shop   = tfe_project.web_shop.id
  }

  team_id    = tfe_team.auditors.id
  project_id = each.value
  access     = "read"
}

# --- Wiring between workspaces --------------------------------------------

# Only web-shop-prod may read network-prod's outputs.
resource "tfe_workspace_settings" "network_prod" {
  workspace_id              = tfe_workspace.network_prod.id
  global_remote_state       = false
  remote_state_consumer_ids = [tfe_workspace.web_shop["prod"].id]
}

# When network-prod applies, web-shop-prod plans again.
resource "tfe_run_trigger" "network_to_web_shop" {
  workspace_id  = tfe_workspace.web_shop["prod"].id
  sourceable_id = tfe_workspace.network_prod.id
}
