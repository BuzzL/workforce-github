output "apply" {
  description = "Names of the apply environments, by account name."
  value       = { for k, m in module.apply : k => m.environment }
}

output "plan" {
  description = "Names of the plan environments, by account name."
  value       = { for k, m in module.plan : k => m.environment }
}
