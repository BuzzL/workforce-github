variable "repository" {
  description = "Name of the repository (without the owner) the environment belongs to."
  type        = string
}

variable "environment" {
  description = "Name of the environment: test, quality, demo, an account (management, security, workforce), github (the Terraform stack of this repository), agent-app, <name>-plan of any of those except agent-app, or <name>-matrix of test, quality and demo (the permission-matrix CI environments). Names are explanatory; the four-letter keys (root, scrt, wrkf, test, qual, demo) are for AWS naming conventions in workforce-infra and are not accepted here."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,38}$", var.environment))
    error_message = "The environment name must be lowercase letters, digits or hyphens."
  }

  # An explicit allowlist, so nothing has to opt in and a new stack cannot skip it. The names
  # are the explanatory ones used everywhere else: the environments test, quality and demo,
  # the accounts management, security and workforce, github (the live/github stack itself), the
  # release App environment agent-app, the plan environment of any of the first seven, and the
  # permission-matrix environment (<name>-matrix) of test, quality and demo. The retired qa and
  # the key qual are refused. A new name is a reviewed change to these lists.
  validation {
    condition = (
      contains(["test", "quality", "demo", "management", "security", "workforce", "github", "agent-app"], var.environment) ||
      (endswith(var.environment, "-plan") && contains(["test", "quality", "demo", "management", "security", "workforce", "github"], trimsuffix(var.environment, "-plan"))) ||
      (endswith(var.environment, "-matrix") && contains(["test", "quality", "demo"], trimsuffix(var.environment, "-matrix")))
    )
    error_message = "The environment name must be one of test, quality, demo, management, security, workforce, github, agent-app, <name>-plan of one of the first seven, or <name>-matrix of test, quality or demo."
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

variable "secret_names" {
  description = "Names of the secrets the environment expects, values set out of band. Only the names live in code: a secret value set through Terraform would be kept in the state, so this never carries one. The names document the contract and are asserted in terraform test; the maintainer sets the values on the environment later. SCREAMING_SNAKE_CASE, so a value (NAME=value) or a lowercase name is refused."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for n in var.secret_names : can(regex("^[A-Z][A-Z0-9_]*$", n))])
    error_message = "A secret name is SCREAMING_SNAKE_CASE (uppercase letters, digits and underscores, starting with a letter) and carries no value: declare names only, never values."
  }

  validation {
    condition     = length(var.secret_names) == length(toset(var.secret_names))
    error_message = "A secret name must not be declared twice."
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
