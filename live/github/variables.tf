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
  description = "ID of the write GitHub App."
  type        = string
}

variable "app_installation_id" {
  description = "Installation ID of the write GitHub App on the workforce repositories."
  type        = string
}

variable "app_pem" {
  description = "Private key of the write App, read from AWS at run time."
  type        = string
  sensitive   = true
}
