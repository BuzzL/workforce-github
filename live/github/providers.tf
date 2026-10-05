# The write App (docs/GITHUB_AS_CODE.md): its key is read from AWS at run time and handed in
# through the environment, never committed. The pem is the content of the key, not a path.
provider "github" {
  owner = var.github_owner

  app_auth {
    id              = var.app_id
    installation_id = var.app_installation_id
    pem_file        = var.app_pem
  }
}
