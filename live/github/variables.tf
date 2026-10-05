variable "github_owner" {
  description = "Owner of the repositories: the personal account."
  type        = string
  default     = "BuzzL"
}

variable "maintainer_user_id" {
  description = "Numeric GitHub ID of the maintainer, the required reviewer of every apply environment. Public, not a secret."
  type        = number
  default     = 6116516
}

variable "aws_region" {
  description = "Region of the environment accounts, set as the plain variable AWS_REGION of each environment."
  type        = string
}

variable "app_id" {
  description = "ID of the write GitHub App. Null falls back to the maintainer's GITHUB_TOKEN for a local apply."
  type        = string
  default     = null
}

variable "app_installation_id" {
  description = "Installation ID of the write GitHub App on the workforce repositories."
  type        = string
  default     = null

  validation {
    condition     = (var.app_id == null || var.app_id == "") == (var.app_installation_id == null || var.app_installation_id == "")
    error_message = "app_id and app_installation_id are set together, or both left null or empty for the GITHUB_TOKEN fallback."
  }
}

variable "app_pem" {
  description = "Private key of the write App, read from AWS at run time."
  type        = string
  sensitive   = true
  default     = null

  validation {
    condition     = (var.app_id == null || var.app_id == "") == (var.app_pem == null || var.app_pem == "")
    error_message = "app_pem is set together with app_id, or both left null or empty for the GITHUB_TOKEN fallback."
  }
}

variable "require_app_auth" {
  description = "Set by the CI workflow: refuses to run unless the whole write App credential is given, so CI can never fall back to a token. Left false only for a local apply by the maintainer."
  type        = bool
  default     = false

  validation {
    condition = !var.require_app_auth || alltrue([
      for v in [var.app_id, var.app_installation_id, var.app_pem] : v != null && v != ""
    ])
    error_message = "require_app_auth is set: app_id, app_installation_id and app_pem must all be given (the token fallback is not allowed here)."
  }
}
