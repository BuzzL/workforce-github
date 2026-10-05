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
}
