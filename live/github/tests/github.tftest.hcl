# Literal assertions on purpose: a change to a protection rule must show up as a diff here.
mock_provider "github" {}

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
