variable "repository" {
  description = "Name of the repository (without the owner) the environment belongs to."
  type        = string
}

variable "environment" {
  description = "Name of the environment: test, quality, demo, an account (management, security, workforce), github (the Terraform stack of this repository), agent-app, or <name>-plan of any of those except agent-app. Names are explanatory; the four-letter keys (root, scrt, wrkf, test, qual, demo) are for AWS naming conventions in workforce-infra and are not accepted here."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,38}$", var.environment))
    error_message = "The environment name must be lowercase letters, digits or hyphens."
  }

  # An explicit allowlist, so nothing has to opt in and a new stack cannot skip it. The names
  # are the explanatory ones used everywhere else: the environments test, quality and demo,
  # the accounts management, security and workforce, github (the live/github stack itself), the
  # release App environment agent-app, and the plan environment of any of the first seven. The retired qa and the key qual are
  # refused. A new name is a reviewed change to these lists.
  validation {
    condition = (
      contains(["test", "quality", "demo", "management", "security", "workforce", "github", "agent-app"], var.environment) ||
      (endswith(var.environment, "-plan") && contains(["test", "quality", "demo", "management", "security", "workforce", "github"], trimsuffix(var.environment, "-plan")))
    )
    error_message = "The environment name must be one of test, quality, demo, management, security, workforce, github, agent-app, or <name>-plan of one of the first seven."
  }
}

variable "owner_type" {
  description = "Whether the repository owner is a personal account (user) or an organization. Team reviewers exist only for organizations."
  type        = string
  default     = "user"

  validation {
    condition     = contains(["user", "organization"], var.owner_type)
    error_message = "owner_type must be user or organization."
  }
}

variable "reviewer_user_ids" {
  description = "Numeric GitHub IDs of the users who must approve a deployment. Empty for an environment that needs no approval (a plan environment). Public IDs, not secrets."
  type        = list(number)
  default     = []

  validation {
    condition     = alltrue([for id in var.reviewer_user_ids : id > 0 && id == floor(id)])
    error_message = "User IDs must be positive whole numbers."
  }

  # GitHub allows at most 6 reviewers (users and teams together) and rejects more at apply time.
  validation {
    condition     = length(var.reviewer_user_ids) + length(var.reviewer_team_ids) <= 6
    error_message = "An environment can have at most 6 reviewers."
  }
}

variable "reviewer_team_ids" {
  description = "Numeric IDs of the teams who must approve a deployment. Organizations only."
  type        = list(number)
  default     = []

  validation {
    condition     = length(var.reviewer_team_ids) == 0 || var.owner_type == "organization"
    error_message = "Team reviewers exist only for organization-owned repositories."
  }
}

variable "can_admins_bypass" {
  description = "Whether repository admins can bypass the protection rules. Required, no default: GitHub's own default is true, so every call states it. False for an environment that unlocks a role that can write; true only reproduces an existing bare environment."
  type        = bool
}

variable "prevent_self_review" {
  description = "Whether the person who triggered a deployment cannot approve it. False while the maintainer is the only reviewer."
  type        = bool
  default     = false
}

variable "deployment_branches" {
  description = "Branch names (or patterns) that may deploy to the environment. Empty means any branch."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for b in var.deployment_branches : length(trimspace(b)) > 0])
    error_message = "A deployment branch must not be empty."
  }
}

variable "variables" {
  description = "Plain (non-secret) environment variables, name to value, such as AWS_REGION. Variables are not masked in the logs of a public repository and live in the Terraform state: a name that looks like a secret or one of the values CI keeps secret is rejected."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for k in keys(var.variables) : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k)) && !startswith(upper(k), "GITHUB_")])
    error_message = "A variable name uses letters, digits and underscores, does not start with a digit and does not start with GITHUB_."
  }

  validation {
    condition     = alltrue([for k in keys(var.variables) : !can(regex("(?i)(secret|token|key|password|role_arn|role_id|state_bucket)", k))])
    error_message = "That name looks like a secret (secret, token, key, password, role ARN or ID, state bucket): secrets are set out of band, not as variables."
  }
}
