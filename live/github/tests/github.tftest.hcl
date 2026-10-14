# Literal assertions on purpose: a change to a protection rule must show up as a diff here.
mock_provider "github" {}

# A mocked provider cannot import; the override stands in for the imported ruleset.
override_resource {
  target = github_repository_ruleset.infra_main
}

variables {
  aws_region = "eu-west-1"
}

run "environments_are_named_not_keyed" {
  command = apply

  assert {
    condition     = toset(keys(module.apply)) == toset(["demo", "quality", "test"]) && module.apply["quality"].environment == "quality"
    error_message = "The apply environments are test, quality and demo: names, never the keys."
  }

  assert {
    condition     = toset(keys(module.plan)) == toset(["demo", "quality", "test"]) && module.plan["quality"].environment == "quality-plan"
    error_message = "Each environment has a <name>-plan twin."
  }
}

run "apply_environments_are_guarded" {
  command = apply

  assert {
    condition = alltrue([
      for m in module.apply :
      m.reviewer_user_ids == toset([6116516]) && m.can_admins_bypass == false && m.deployment_restricted == true && m.deployment_branches == toset(["main"]) && m.variables == { AWS_REGION = "eu-west-1" }
    ])
    error_message = "An apply environment needs the maintainer as reviewer, no admin bypass and main only."
  }
}

run "plan_environments_have_no_reviewer_and_any_branch" {
  command = apply

  assert {
    condition = alltrue([
      for m in module.plan :
      length(m.reviewer_user_ids) == 0 && m.deployment_restricted == false && length(m.deployment_branches) == 0 && m.variables == { AWS_REGION = "eu-west-1" }
    ])
    error_message = "A plan environment has no reviewer, accepts any branch and carries the region. That it unlocks only a read-only role is a property of the baseline in workforce-infra."
  }
}

run "the_github_stack_environments_are_guarded" {
  command = apply

  assert {
    condition = (
      module.github_apply.environment == "github" && module.github_apply.variables == { AWS_REGION = "eu-west-1" } && module.github_apply.reviewer_user_ids == toset([6116516]) &&
      module.github_apply.can_admins_bypass == false && module.github_apply.deployment_restricted == true &&
      module.github_apply.deployment_branches == toset(["main"])
    )
    error_message = "The github environment needs the maintainer as reviewer, no admin bypass and main only."
  }

  assert {
    condition = (
      module.github_plan.environment == "github-plan" && module.github_plan.variables == { AWS_REGION = "eu-west-1" } && length(module.github_plan.reviewer_user_ids) == 0 &&
      module.github_plan.deployment_restricted == false && length(module.github_plan.deployment_branches) == 0
    )
    error_message = "The github-plan environment has no reviewer and accepts any branch."
  }
}

run "matrix_environments_are_named_with_their_secrets" {
  command = apply

  assert {
    condition     = toset(keys(module.matrix)) == toset(["demo", "quality", "test"]) && module.matrix["quality"].environment == "quality-matrix"
    error_message = "The matrix environments are test-matrix, quality-matrix and demo-matrix: the names with -matrix, never the keys."
  }

  assert {
    condition = alltrue([
      for m in module.matrix :
      m.secret_names == toset(["MATRIX_RUNNER_ROLE_ARN", "MATRIX_AGENT_ROLE_ARN", "MATRIX_EXTERNAL_ID", "MATRIX_VIA_ROLE_ARN"]) && m.variables == { AWS_REGION = "eu-west-1" }
    ])
    error_message = "Each matrix environment declares the four matrix secret names (values out of band) and carries the region."
  }
}

run "demo_matrix_is_reviewer_gated_and_the_others_are_not" {
  command = apply

  assert {
    condition = (
      module.matrix["demo"].reviewer_user_ids == toset([6116516]) && module.matrix["demo"].can_admins_bypass == false &&
      module.matrix["demo"].deployment_restricted == true && module.matrix["demo"].deployment_branches == toset(["main"])
    )
    error_message = "demo-matrix is the demo reviewer gate: the maintainer as reviewer, no admin bypass and main only."
  }

  assert {
    condition = alltrue([
      for k in ["test", "quality"] :
      length(module.matrix[k].reviewer_user_ids) == 0 && module.matrix[k].deployment_restricted == false && length(module.matrix[k].deployment_branches) == 0
    ])
    error_message = "test-matrix and quality-matrix need no reviewer and accept any branch."
  }
}

# The App is all or nothing: half a credential must not silently fall back to the token.
run "an_app_id_without_its_key_is_refused" {
  command = plan

  variables {
    app_id = "1"
  }

  expect_failures = [var.app_installation_id, var.app_pem]
}

run "the_app_credential_is_accepted_whole" {
  command = plan

  variables {
    app_id              = "1"
    app_installation_id = "2"
    app_pem             = "pem"
  }

  # The mocked provider is never configured, so this mirrors the selection made in providers.tf.
  assert {
    condition     = output.auth_mode == "app"
    error_message = "With an app_id the provider authenticates as the App."
  }
}

run "no_app_means_the_token_fallback" {
  command = plan

  assert {
    condition     = output.auth_mode == "token"
    error_message = "Without an app_id the provider falls back to the maintainer's token."
  }
}

run "an_empty_app_id_counts_as_unset" {
  command = plan

  variables {
    app_id              = ""
    app_installation_id = ""
    app_pem             = ""
  }

  assert {
    condition     = output.auth_mode == "token"
    error_message = "Empty values, such as a missing CI secret, count as unset."
  }
}

run "an_empty_app_id_with_a_key_is_refused" {
  command = plan

  variables {
    app_id              = ""
    app_installation_id = "2"
    app_pem             = "pem"
  }

  expect_failures = [var.app_installation_id, var.app_pem]
}

# CI sets require_app_auth, so a missing or empty App credential fails instead of falling back.
run "required_app_auth_refuses_the_token_fallback" {
  command = plan

  variables {
    require_app_auth = true
  }

  expect_failures = [var.require_app_auth]
}

run "required_app_auth_refuses_empty_values" {
  command = plan

  variables {
    require_app_auth    = true
    app_id              = ""
    app_installation_id = ""
    app_pem             = ""
  }

  expect_failures = [var.require_app_auth]
}

run "required_app_auth_refuses_a_partial_credential" {
  command = plan

  variables {
    require_app_auth    = true
    app_id              = "1"
    app_installation_id = "2"
    app_pem             = ""
  }

  expect_failures = [var.app_pem]
}

run "required_app_auth_accepts_the_whole_credential" {
  command = plan

  variables {
    require_app_auth    = true
    app_id              = "1"
    app_installation_id = "2"
    app_pem             = "pem"
  }

  assert {
    condition     = output.auth_mode == "app" && output.app_auth_required == true
    error_message = "With the whole credential and require_app_auth the provider authenticates as the App."
  }
}

run "the_infra_main_ruleset_keeps_its_protection" {
  command = apply

  assert {
    condition = (
      github_repository_ruleset.infra_main.repository == "workforce-infra" && github_repository_ruleset.infra_main.enforcement == "active" &&
      length(github_repository_ruleset.infra_main.bypass_actors) == 0 &&
      github_repository_ruleset.infra_main.conditions[0].ref_name[0].include == tolist(["~DEFAULT_BRANCH"]) &&
      github_repository_ruleset.infra_main.rules[0].deletion == true && github_repository_ruleset.infra_main.rules[0].non_fast_forward == true
    )
    error_message = "The main ruleset of workforce-infra targets the default branch, blocks deletion and force pushes, and has no bypass actors."
  }

  assert {
    condition = (
      github_repository_ruleset.infra_main.rules[0].pull_request[0].required_approving_review_count == 1 &&
      github_repository_ruleset.infra_main.rules[0].pull_request[0].dismiss_stale_reviews_on_push == true &&
      github_repository_ruleset.infra_main.rules[0].pull_request[0].require_code_owner_review == true &&
      github_repository_ruleset.infra_main.rules[0].pull_request[0].require_last_push_approval == true &&
      github_repository_ruleset.infra_main.rules[0].pull_request[0].required_review_thread_resolution == true &&
      github_repository_ruleset.infra_main.rules[0].pull_request[0].allowed_merge_methods == tolist(["squash"])
    )
    error_message = "A pull request to main needs one code-owner approval after the last push, resolved threads, and is squash-merged."
  }

  assert {
    condition = alltrue([
      for c in github_repository_ruleset.infra_main.rules[0].required_status_checks[0].required_check : c.integration_id == 15368
    ])
    error_message = "Every required check must come from GitHub Actions."
  }
}

# A skipped job reports its unexpanded name, so the matrix checks cannot be required by default.
run "the_permission_matrix_is_not_required_by_default" {
  command = apply

  assert {
    condition     = output.infra_required_checks == sort(["gitleaks", "tooling-selftest", "conventions", "tflint", "validate", "fmt", "tf-test", "trivy", "workflows"])
    error_message = "By default the required checks are the nine CI checks, without the permission matrix."
  }
}

run "the_permission_matrix_can_be_required" {
  command = apply

  variables {
    require_permission_matrix = true
  }

  assert {
    condition = output.infra_required_checks == sort([
      "gitleaks", "tooling-selftest", "conventions", "tflint", "validate", "fmt", "tf-test", "trivy", "workflows",
      "permission-matrix agent test", "permission-matrix agent quality", "permission-matrix agent demo",
    ])
    error_message = "With require_permission_matrix the three expanded permission-matrix checks are required too."
  }

  assert {
    condition     = alltrue([for c in output.infra_required_checks : !strcontains(c, "$${{")])
    error_message = "An unexpanded job name is what a skipped job reports; requiring it would pass a skipped matrix."
  }
}
