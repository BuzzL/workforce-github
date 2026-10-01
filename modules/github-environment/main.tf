locals {
  protected = length(var.reviewer_user_ids) + length(var.reviewer_team_ids) > 0
}

# The protection of the environment is the only guard on the cloud role it unlocks.
# Secrets are not managed here on purpose: a secret value set through Terraform is kept in
# the state, so they are set out of band (docs/GITHUB_AS_CODE.md).
resource "github_repository_environment" "this" {
  repository          = var.repository
  environment         = var.environment
  can_admins_bypass   = var.can_admins_bypass
  prevent_self_review = var.prevent_self_review

  dynamic "reviewers" {
    for_each = local.protected ? [1] : []

    content {
      users = var.reviewer_user_ids
      teams = var.reviewer_team_ids
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = length(var.deployment_branches) > 0 ? [1] : []

    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }
}

resource "github_repository_environment_deployment_policy" "branch" {
  for_each = toset(var.deployment_branches)

  repository     = var.repository
  environment    = github_repository_environment.this.environment
  branch_pattern = each.value
}

resource "github_actions_environment_variable" "this" {
  for_each = var.variables

  repository    = var.repository
  environment   = github_repository_environment.this.environment
  variable_name = each.key
  value         = each.value
}
