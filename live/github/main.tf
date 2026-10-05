# The GitHub Environments of the environment accounts (IAT-79). The baseline roles of
# bootstrap/accounts/<name> in workforce-infra trust one subject per environment of
# workforce-infra, so the environments belong to that repository.
#
# Each account has an apply environment (the maintainer must approve, no admin bypass, main
# only) for the read-write role, and a <name>-plan environment (no reviewer, any branch) that
# may only ever unlock the read-only role. The secrets AWS_ROLE_ARN, AWS_ROLE_ID and
# STATE_BUCKET are set out of band from the baseline stack outputs, never here: a secret set
# through Terraform would be kept in the state (docs/GITHUB_AS_CODE.md).
locals {
  repository   = "workforce-infra"
  environments = toset(["test", "quality", "demo"])
}

module "apply" {
  source   = "../../modules/github-environment"
  for_each = local.environments

  repository          = local.repository
  environment         = each.key
  reviewer_user_ids   = [var.maintainer_user_id]
  can_admins_bypass   = false
  deployment_branches = ["main"]
  variables           = { AWS_REGION = var.aws_region }
}

module "plan" {
  source   = "../../modules/github-environment"
  for_each = local.environments

  repository = local.repository
  # Pull requests plan in it, so no reviewer and any branch. Admin bypass has nothing to
  # protect on a read-only role.
  environment       = "${each.key}-plan"
  can_admins_bypass = true
  variables         = { AWS_REGION = var.aws_region }
}

# The environments of this repository's own CI (IAT-89). github-infra-github and
# github-infra-github-plan in workforce-infra trust one subject per environment: apply (the
# maintainer must approve, no admin bypass, main only) unlocks the role that writes the state
# and reads the write App's key, and github-plan (no reviewer, any branch) only the read-only
# role. Their secrets are set out of band, like the others.
module "github_apply" {
  source = "../../modules/github-environment"

  repository          = "workforce-github"
  environment         = "github"
  reviewer_user_ids   = [var.maintainer_user_id]
  can_admins_bypass   = false
  deployment_branches = ["main"]
  variables           = { AWS_REGION = var.aws_region }
}

module "github_plan" {
  source = "../../modules/github-environment"

  repository        = "workforce-github"
  environment       = "github-plan"
  can_admins_bypass = true
  variables         = { AWS_REGION = var.aws_region }
}
