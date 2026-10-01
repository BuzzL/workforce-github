variable "repository" {
  description = "Name of the repository (without the owner) the environment belongs to."
  type        = string
}

variable "environment" {
  description = "Name of the environment. Lowercase, as everywhere else: test, qa, demo, an account name or <name>-plan."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,38}$", var.environment))
    error_message = "The environment name must be lowercase letters, digits or hyphens."
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
  description = "Whether repository admins can bypass the protection rules. False for an environment that unlocks a role that can write."
  type        = bool
  default     = false
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
  description = "Plain (non-secret) environment variables, name to value, such as AWS_REGION. Secrets are never set here: their values would end up in the Terraform state."
  type        = map(string)
  default     = {}
}
