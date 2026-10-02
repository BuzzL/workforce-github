variable "repository" {
  description = "Name of the repository (without the owner) the environment belongs to."
  type        = string
}

variable "environment" {
  description = "Name of the environment. Lowercase, as everywhere else: test, qual, demo, an account name or <name>-plan. Exactly four lowercase letters (test, qual, demo), <name>-plan, or one of management, security, workforce, agent-app."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,38}$", var.environment))
    error_message = "The environment name must be lowercase letters, digits or hyphens."
  }

  # A deployable environment is exactly four lowercase letters (test, qual, demo), so AWS
  # policies and role-name patterns can match it strictly. The only other names are the plan
  # environment of any of them (<name>-plan) and the named exceptions that are accounts or
  # the release App, not deployable environments. A new exception is a reviewed change here.
  validation {
    condition = (
      can(regex("^[a-z]{4}$", var.environment)) ||
      can(regex("^[a-z][a-z0-9]*-plan$", var.environment)) ||
      contains(["management", "security", "workforce", "agent-app"], var.environment)
    )
    error_message = "An environment name must be exactly four lowercase letters (test, qual, demo), <name>-plan, or one of management, security, workforce, agent-app."
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
