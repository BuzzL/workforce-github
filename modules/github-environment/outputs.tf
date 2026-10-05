output "environment" {
  description = "Name of the environment."
  value       = github_repository_environment.this.environment
}

output "can_admins_bypass" {
  description = "Whether repository admins can bypass the protection rules."
  value       = github_repository_environment.this.can_admins_bypass
}

output "reviewer_user_ids" {
  description = "IDs of the users who must approve a deployment. Empty when the environment needs no approval."
  value       = toset(flatten([for r in github_repository_environment.this.reviewers : tolist(r.users)]))
}

output "deployment_branches" {
  description = "Branch patterns that may deploy to the environment. Empty means any branch."
  value       = toset([for p in github_repository_environment_deployment_policy.branch : p.branch_pattern])
}

output "deployment_restricted" {
  description = "Whether only the listed branches may deploy (custom deployment policies on). False means any branch."
  value       = length(github_repository_environment.this.deployment_branch_policy) > 0 ? one(github_repository_environment.this.deployment_branch_policy).custom_branch_policies : false
}

output "variables" {
  description = "Plain variables of the environment, name to value."
  value       = { for k, v in github_actions_environment_variable.this : k => v.value }
}
