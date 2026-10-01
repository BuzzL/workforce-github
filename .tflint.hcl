# Enforces the versions.tf convention: every stack and module declares
# `required_version` (>= 1.9) and pins its providers (GitHub ~> 6).
config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}
