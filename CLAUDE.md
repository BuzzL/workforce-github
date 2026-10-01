# workforce-github

GitHub as code for the AI Workforce: Terraform that manages the `workforce-*` repos (settings, `main` ruleset, GitHub Environments). Cross-repo context lives in the workspace `CLAUDE.md` one level up, when it's present. Decisions are recorded in `docs/GITHUB_AS_CODE.md`.

## Rules

- **Commit rule**: every commit is short (one logical change), testable (`terraform validate`, `terraform test` with a mocked GitHub provider, tflint) and not breakable (CI green on its own). Conventional Commits.
- Changes land on `main` only through a squash-merged PR with green CI and the maintainer's approval.
- Public repo: never commit tokens, App keys, state, `*.tfvars` or `backend.hcl`. Commit `*.example` files instead. Do not commit AWS account IDs, ARNs or emails either.
- Protection of an environment is the only guard on the role it unlocks: an apply environment has a required reviewer, no admin bypass and `main` only; a plan environment has no reviewer and must only ever unlock a read-only role.
- Environment names are the lowercase names used everywhere else (`test`, `qa`, `demo`, account names, `<name>-plan`).

## Scope

This repo is the **GitHub provider** side of the workforce: repos, rulesets, GitHub Environments. AWS resources (accounts, roles, the state bucket, the OIDC roles this repo's CI assumes) are the **AWS provider** side and live in `workforce-infra`; a cross-repo need is one PR per repo. Secrets are not managed in Terraform (the values would land in the state); they are set out of band.

## Layout

- `live/` and `modules/` are the only places Terraform may live: `scripts/stacks.sh` fails on a `.tf` anywhere else, so no gate can skip it.
- `live/`: root stacks (Terraform), each with its own state key. None yet.
- `modules/`: reusable modules, each with mocked `terraform test`s. None yet.
- `docs/GITHUB_AS_CODE.md`: decision record (credential, personal account vs organization, import, secrets).
- `Makefile`, `scripts/`: `make check` runs fmt, validate, tflint, version and Dependabot conventions, trivy (secrets and config scan only: it has no checks for GitHub settings, so protection is proven by literal assertions in `terraform test`), `terraform test` and actionlint. CI runs the same targets. Loops live in `scripts/each.sh`, not in recipes (macOS Make 3.81). Terraform version: `.terraform-version`.
- Each stack or module declares `required_version` (>= 1.9) and pins the GitHub provider (`integrations/github`) to `~> 6`; `make versions` enforces the values, tflint that constraints exist. A stack that declares providers must be in the terraform block of `.github/dependabot.yml` (`make dependabot`).
