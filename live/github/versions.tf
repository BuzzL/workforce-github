terraform {
  required_version = ">= 1.10"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # Partial configuration: the bucket and region come from backend.hcl; the key is
  # live/github/terraform.tfstate.
  backend "s3" {
    use_lockfile = true
    encrypt      = true
  }
}
