# GitHub as code: spike record (IAT-27)

Status: **decided** by the maintainer on 2026-09-30 (see Decisions). The spike's *(verify)* items are still to be exercised. Facts marked *(verify)* come from GitHub documentation and have not been exercised against this account yet.

## Current state (read from the API, no changes made)

The four repos (`workforce-infra`, `workforce-images`, `workforce-testbed`, `workforce-github`) are public, Apache-2.0, squash-only, delete-branch-on-merge, wiki off, secret scanning and push protection on. Each has a `main` ruleset with no bypass actors: deletion and non-fast-forward blocked, one code-owner approval, stale reviews dismissed on push, last-push approval, thread resolution, squash only, required status checks. `images` and `testbed` also have `protect-release-tags`. `workforce-github` was created by hand and has none of this yet (no ruleset, merge commits allowed); it must be brought in line by hand before its first PR merges, then imported. Environments today: infra `development`, `management`, `management-plan`, `production`; images `agent-app`; testbed `agent-app`, `development`, `production`. The module takes environments as input; `development`/`production` are renamed by IAT-20 (IAT-26 decided the model).

Consequence: everything the module must express already exists, so importing is the test of the module. A clean `terraform plan` after import proves it.

## Credential

| Option | Verdict |
|---|---|
| Static PAT in GitHub secrets | Rejected: long-lived key, breaks the "no static keys" rule. |
| GitHub App key in Secrets Manager or SSM, fetched by the CI job through the OIDC role | **Preferred.** The installation token is short-lived (1 h) and access is one more scoped IAM statement. The PEM itself is fetched onto the runner and held in memory by the provider (`app_auth`), so it does leave AWS for the job's lifetime. Stronger variant, not adopted yet: import the key into KMS, sign the App JWT with `kms:Sign`, and hand only the installation token to the provider. |
| Maintainer token, local apply only | Fallback for what an App cannot do (see below). Explicit yes per apply. |

The provider is configured with `app_auth` (App ID, installation ID, PEM) read at run time. None of those values is committed.

Expected minimal App permissions *(verify, the list is not exercised yet)*: repository *Administration* (write; also needed to create environments and set reviewers), *Environments* (write; environment secrets and variables), *Secrets* (write; repo-level secrets), *Variables* (write), *Metadata* (read). *Administration* can change branch protection, collaborators and visibility and can delete repos, so a leaked key is close to full control of every repo it is installed on. Mitigations: a dedicated App separate from the agent App (IAT-23), installed only on `workforce-*` repos, apply behind an environment approval. **Plan needs a credential too**: rulesets, environments and security settings are admin-scoped reads. The plan role therefore gets its own read-only App (Administration read, Environments read, Secrets read, Variables read, Metadata read), and only the apply role can read the write App's key.

## Personal account vs organization

| Capability | Personal (`BuzzL`) | Organization |
|---|---|---|
| Create repo with App token | Not possible *(verify)*: `POST /user/repos` needs a user token | Possible with Administration on the org *(verify)* |
| Repo settings, topics, rulesets on an existing repo | Possible with App installed on the repo *(verify)* | Possible |
| Environments, reviewers | Users only | Users and teams |
| Secrets and variables per repo/environment | Possible | Possible, plus org-level secrets and rulesets |
| CODEOWNERS teams | Not available | Available |

Superseded by Decision 2 below for repo creation. Still valid: one variable `owner_type = "user" | "organization"`. Org-only resources sit behind `count = owner_type == "organization" ? 1 : 0`. (The earlier proposal to create personal repos by hand and import them was rejected.) Another creation path exists: `POST /user/repos` accepts a GitHub App *user access token* (8 h, device flow), sitting between an installation token and a `gh` token *(verify)*.

The maintainer account also belongs to one organization, which may allow the "org" leg of the done-criteria to be tested without creating one. Not touched yet, needs an explicit yes.

## Where it lives

Decided: a separate repo, `workforce-github`. It reuses the state bucket but keeps `workforce-infra` scoped to AWS. Cost: the plan/apply gates are duplicated here.

## Guard rails

- The App can delete repos (Administration) but cannot create them on a personal account, so a planned replacement of `github_repository` would delete and then fail. The module sets `lifecycle { prevent_destroy = true }` and `archive_on_destroy = true`, and CI only applies a plan with no creates or deletes of repositories (creation stays a local apply).
- Secret values end up in Terraform state. **Decided: secrets are not managed in Terraform.** `integrations/github` v6.13.0 has no write-only attribute or ephemeral resource for environment secrets, and Terraform cannot seal a value with GitHub's public key itself, so any value it writes lands in the state. The environments and their protection are in Terraform (`modules/github-environment`); the secrets (`AWS_ROLE_ARN`, `AWS_ROLE_ID`, `STATE_BUCKET`) are set out of band by `scripts/set-account-environment-secrets.sh` in workforce-infra from the stack outputs, and only their names are checked. `make versions` fails if a `github_*secret*` resource appears. Rejected: SOPS-encrypted values decrypted by Terraform (the values still reach the state, and the ciphertext would be public), pre-sealed `encrypted_value` (needs a script anyway).

## Import check

Not run yet. Plan: write the module, import the three repos, expect no diff. Known risks: `require_extra_approval_for_unattributed_changes` is true on infra and testbed but false on images, so one default gives a diff somewhere (make it an input); ruleset `integration_id` for required checks (15368, GitHub Actions) and `required_reviewers` must be expressible in the provider, otherwise the plan will show drift.

## Decisions (maintainer, 2026-09-30)

1. **Credential**: GitHub App key in AWS, fetched through the OIDC role, with the mitigations above. Accepted.
2. **Personal account**: repos are created **by Terraform**, not by hand. An App installation token cannot create user repos *(verify)*, so creation runs only as a **local apply with the maintainer's own `gh` token and an explicit yes per apply**. CI uses the App for everything that is not creation (settings, rulesets, environments, secrets), and a CI plan must not need creation rights.
3. **Where it lives**: this repo, `workforce-github`, not `workforce-infra`. It needs its own state key in the existing state bucket, its own GitHub Environments and OIDC roles (created from `workforce-infra`), and its own copy of the plan/apply gates. `workforce-infra` CLAUDE.md scope stays AWS only.
4. **Organization test**: no. The org leg of the done-criteria stays untested unless a throwaway org is provided later; the org code path is covered by `terraform test` with a mocked provider only.

## Consequences

- Bootstrapping: `workforce-github` was created by hand once (it cannot manage itself before it exists). Its first real task is importing itself along with the three other repos.
- The state bucket and OIDC roles for this repo come from `workforce-infra` (separate PR there).
- The workspace `CLAUDE.md` table lists `workforce-github`.

## Next

1. `modules/github-repo` with mocked `terraform test` (ruleset, no bypass, environments, both owner types).
2. `live/github` stack importing the four existing repos, plan shows no drift.
3. Infra PR: state key and roles for this repo.
