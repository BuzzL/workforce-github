# Literal assertions on purpose: a change to a protection rule must show up as a diff here.
mock_provider "github" {}

# The apply environment of an account: the only guard on a role that can write state.
run "apply_environment_is_protected" {
  command = apply

  variables {
    repository          = "workforce-infra"
    environment         = "security"
    reviewer_user_ids   = [6116516]
    can_admins_bypass   = false
    prevent_self_review = false
    deployment_branches = ["main"]
    variables           = { AWS_REGION = "eu-west-1" }
  }

  assert {
    condition     = github_repository_environment.this.environment == "security" && github_repository_environment.this.repository == "workforce-infra"
    error_message = "The environment must be created in the given repository under the given name."
  }

  assert {
    condition     = github_repository_environment.this.can_admins_bypass == false
    error_message = "Administrators must not be able to bypass the protection of an apply environment."
  }

  assert {
    condition     = github_repository_environment.this.prevent_self_review == false
    error_message = "The maintainer is the only reviewer, so self review must stay allowed."
  }

  assert {
    condition     = one(github_repository_environment.this.reviewers).users == toset([6116516]) && length(one(github_repository_environment.this.reviewers).teams) == 0
    error_message = "The apply environment needs exactly the maintainer as required reviewer."
  }

  assert {
    condition     = one(github_repository_environment.this.deployment_branch_policy).custom_branch_policies == true && one(github_repository_environment.this.deployment_branch_policy).protected_branches == false
    error_message = "Only the listed branches may deploy: custom branch policies on."
  }

  assert {
    condition     = keys(github_repository_environment_deployment_policy.branch) == ["main"] && github_repository_environment_deployment_policy.branch["main"].branch_pattern == "main"
    error_message = "Only main may deploy to the apply environment."
  }

  assert {
    condition     = keys(github_actions_environment_variable.this) == ["AWS_REGION"] && github_actions_environment_variable.this["AWS_REGION"].value == "eu-west-1"
    error_message = "The region is a plain variable of the environment."
  }
}

# The plan environment: no reviewer and any branch, on purpose, because pull requests plan in it.
run "plan_environment_has_no_reviewer_and_any_branch" {
  command = apply

  variables {
    repository        = "workforce-infra"
    environment       = "security-plan"
    can_admins_bypass = true
  }

  assert {
    condition     = length(github_repository_environment.this.reviewers) == 0
    error_message = "A plan environment has no required reviewer."
  }

  assert {
    condition     = length(github_repository_environment.this.deployment_branch_policy) == 0 && length(github_repository_environment_deployment_policy.branch) == 0
    error_message = "A plan environment accepts any branch."
  }

  assert {
    condition     = length(github_actions_environment_variable.this) == 0
    error_message = "No variable unless one is given."
  }
}

run "team_reviewers_need_an_organization" {
  command = plan

  variables {
    repository        = "workforce-infra"
    environment       = "demo"
    reviewer_team_ids = [42]
    can_admins_bypass = false
  }

  expect_failures = [var.reviewer_team_ids]
}

run "team_reviewers_work_for_an_organization" {
  command = apply

  variables {
    repository        = "workforce-infra"
    environment       = "demo"
    owner_type        = "organization"
    reviewer_team_ids = [42]
    can_admins_bypass = false
  }

  assert {
    condition     = one(github_repository_environment.this.reviewers).teams == toset([42])
    error_message = "An organization environment can require a team."
  }
}

run "environment_name_must_be_lowercase" {
  command = plan

  variables {
    repository        = "workforce-infra"
    environment       = "Security"
    can_admins_bypass = false
  }

  expect_failures = [var.environment]
}

run "variables_must_not_look_like_secrets" {
  command = plan

  variables {
    repository        = "workforce-infra"
    environment       = "security"
    can_admins_bypass = false
    variables         = { AWS_ROLE_ARN = "x" }
  }

  expect_failures = [var.variables]
}

run "variable_names_are_validated" {
  command = plan

  variables {
    repository        = "workforce-infra"
    environment       = "security"
    can_admins_bypass = false
    variables         = { GITHUB_REGION = "x" }
  }

  expect_failures = [var.variables]
}

run "at_most_six_reviewers" {
  command = plan

  variables {
    repository        = "workforce-infra"
    environment       = "security"
    can_admins_bypass = false
    reviewer_user_ids = [1, 2, 3, 4, 5, 6, 7]
  }

  expect_failures = [var.reviewer_user_ids]
}

# Environment names are explanatory and come from an explicit allowlist: test, quality, demo,
# management, security, workforce, agent-app, and <name>-plan of the first six. The four-letter
# keys of workforce-infra (qual among them) are for AWS naming conventions and are not names.
# Nothing has to opt in: a new stack cannot skip the rule.
run "quality_is_accepted" {
  command = apply

  variables {
    repository        = "workforce-testbed"
    environment       = "quality"
    can_admins_bypass = true
  }

  assert {
    condition     = github_repository_environment.this.environment == "quality"
    error_message = "The quality environment must be created under that name."
  }
}

run "the_retired_qa_is_refused" {
  command = plan

  variables {
    repository        = "workforce-testbed"
    environment       = "qa"
    can_admins_bypass = true
  }

  expect_failures = [var.environment]
}

run "the_key_qual_is_not_a_name" {
  command = plan

  variables {
    repository        = "workforce-testbed"
    environment       = "qual"
    can_admins_bypass = true
  }

  expect_failures = [var.environment]
}

run "a_name_outside_the_allowlist_is_refused" {
  command = plan

  variables {
    repository        = "workforce-testbed"
    environment       = "staging"
    can_admins_bypass = true
  }

  expect_failures = [var.environment]
}

run "a_hyphenated_name_that_is_not_a_plan_environment_is_refused" {
  command = plan

  variables {
    repository        = "workforce-testbed"
    environment       = "qa-stage"
    can_admins_bypass = true
  }

  expect_failures = [var.environment]
}

run "the_plan_environment_of_agent_app_does_not_exist" {
  command = plan

  variables {
    repository        = "workforce-testbed"
    environment       = "agent-app-plan"
    can_admins_bypass = true
  }

  expect_failures = [var.environment]
}

run "plan_environments_keep_their_names" {
  command = plan

  variables {
    repository        = "workforce-infra"
    environment       = "management-plan"
    can_admins_bypass = true
  }

  assert {
    condition     = github_repository_environment.this.environment == "management-plan"
    error_message = "A <name>-plan environment of an allowed name is accepted."
  }
}

run "an_account_environment_keeps_its_name" {
  command = plan

  variables {
    repository        = "workforce-infra"
    environment       = "workforce"
    can_admins_bypass = true
  }

  assert {
    condition     = github_repository_environment.this.environment == "workforce"
    error_message = "An account environment keeps its name."
  }
}
