output "apply" {
  description = "Names of the apply environments, by account name."
  value       = { for k, m in module.apply : k => m.environment }
}

output "plan" {
  description = "Names of the plan environments, by account name."
  value       = { for k, m in module.plan : k => m.environment }
}

output "auth_mode" {
  description = "How the provider authenticates: app (the write App) or token (GITHUB_TOKEN, a local apply by the maintainer)."
  value       = local.use_app ? "app" : "token"
}

output "app_auth_required" {
  description = "Whether this run refuses the token fallback (set by the CI workflow)."
  value       = var.require_app_auth
}

output "infra_required_checks" {
  description = "Required status checks of the main ruleset of workforce-infra."
  value       = sort([for c in github_repository_ruleset.infra_main.rules[0].required_status_checks[0].required_check : c.context])
}
