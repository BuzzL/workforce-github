# With the write App (docs/GITHUB_AS_CODE.md) its key is read from AWS at run time and handed in
# through the environment, never committed; the pem is the content of the key, not a path.
# Without app_id the provider falls back to GITHUB_TOKEN, the maintainer's own token, for a
# local apply with an explicit yes (the documented fallback). CI never uses the fallback.
locals {
  # An empty value counts as unset, so a missing CI secret cannot half-configure the App.
  use_app = var.app_id != null && var.app_id != ""
}

provider "github" {
  owner = var.github_owner

  dynamic "app_auth" {
    for_each = local.use_app ? [1] : []

    content {
      id              = var.app_id
      installation_id = var.app_installation_id
      pem_file        = var.app_pem
    }
  }
}
