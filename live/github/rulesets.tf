# The main ruleset of workforce-infra, imported as it stands (no bypass actors). The provider
# cannot express require_extra_approval_for_unattributed_changes, which is on today: check it
# after an apply (docs/GITHUB_AS_CODE.md).
#
# The permission-matrix checks are required only with require_permission_matrix. While the
# workflow's MATRIX_ENABLED variable is off, the job is skipped before its matrix expands and
# reports one unexpanded name, so the three expanded names would never arrive and every pull
# request would wait on them forever.
import {
  to = github_repository_ruleset.infra_main
  id = "workforce-infra:24166087"
}

locals {
  infra_required_checks = ["gitleaks", "tooling-selftest", "conventions", "tflint", "validate", "fmt", "tf-test", "trivy", "workflows"]
  permission_matrix_checks = [
    for e in local.environments : "permission-matrix agent ${e}"
  ]
  infra_checks = concat(local.infra_required_checks, var.require_permission_matrix ? local.permission_matrix_checks : [])
  # The GitHub Actions app: a check of the same name from any other source does not count.
  github_actions_app_id = 15368
}

resource "github_repository_ruleset" "infra_main" {
  name        = "main"
  repository  = local.repository
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = 1
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = true
      require_last_push_approval        = true
      required_review_thread_resolution = true
      allowed_merge_methods             = ["squash"]
    }

    required_status_checks {
      strict_required_status_checks_policy = false
      do_not_enforce_on_create             = false

      dynamic "required_check" {
        for_each = toset(local.infra_checks)

        content {
          context        = required_check.value
          integration_id = local.github_actions_app_id
        }
      }
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
