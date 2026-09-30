# GitHub as code: spike record (IAT-27)

Status: **decided** by the maintainer on 2026-09-30 (see Decisions). The spike's *(verify)* items are still to be exercised. Facts marked *(verify)* come from GitHub documentation and have not been exercised against this account yet.

## Current state (read from the API, no changes made)

All three repos (`workforce-infra`, `workforce-images`, `workforce-testbed`) are public, Apache-2.0, squash-only, delete-branch-on-merge, wiki off, secret scanning and push protection on. Each has a `main` ruleset with no bypass actors: deletion and non-fast-forward blocked, one code-owner approval, stale reviews dismissed on push, last-push approval, thread resolution, squash only, required status checks. `images` and `testbed` also have `protect-release-tags`. Environments still use `development` / `production` (renamed by IAT-20 after IAT-26).

Consequence: everything the module must express already exists, so importing is the test of the module. A clean `terraform plan` after import proves it.

## Credential

| Option | Verdict |
|---|---|
| Static PAT in GitHub secrets | Rejected: long-lived key, breaks the "no static keys" rule. |
| GitHub App key in Secrets Manager or SSM, fetched by the CI job through the OIDC role | **Preferred.** Token is short-lived (1 h), key never leaves AWS, access is one more scoped IAM statement. |
| Maintainer token, local apply only | Fallback for what an App cannot do (see below). Explicit yes per apply. |

The provider is configured with `app_auth` (App ID, installation ID, PEM) read at run time. None of those values is committed.

Minimal App permissions for the repo settings in scope: repository *Administration* (write), *Environments* (write), *Secrets* (write), *Metadata* (read). *Administration* can change branch protection, collaborators and visibility and can delete repos, so a leaked key is close to full control of every repo it is installed on. Mitigations: a dedicated App separate from the agent App (IAT-23), installed only on `workforce-*` repos, key only readable by the apply role (not the plan role), apply behind the `management` environment approval.

## Personal account vs organization

| Capability | Personal (`BuzzL`) | Organization |
|---|---|---|
| Create repo with App token | Not possible *(verify)*: `POST /user/repos` needs a user token | Possible with Administration on the org *(verify)* |
| Repo settings, topics, rulesets on an existing repo | Possible with App installed on the repo *(verify)* | Possible |
| Environments, reviewers | Users only | Users and teams |
| Secrets and variables per repo/environment | Possible | Possible, plus org-level secrets and rulesets |
| CODEOWNERS teams | Not available | Available |

Proposed handling: one variable `owner_type = "user" | "organization"`. Org-only resources sit behind `count = owner_type == "organization" ? 1 : 0`. On a personal account repos are **created by hand once and imported**; the module supports `create = false` semantics through import, and the docs list the manual step. This keeps the App key free of a token that can create arbitrary repos.

The maintainer account also belongs to one organization, which may allow the "org" leg of the done-criteria to be tested without creating one. Not touched yet, needs an explicit yes.

## Where it lives

Decided: a separate repo, `workforce-github`. It reuses the state bucket but keeps `workforce-infra` scoped to AWS. Cost: the plan/apply gates are duplicated here.

## Import check

Not run yet. Plan: write the module, import the three repos, expect no diff. Known risk: ruleset `integration_id` for required checks (15368, GitHub Actions) and `required_reviewers` must be expressible in the provider, otherwise the plan will show drift.

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
