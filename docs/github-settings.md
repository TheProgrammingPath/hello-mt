# GitHub settings

Repository settings are the one thing configured outside Terraform (ground rule 1).
They were applied with `gh` from the command line; this file records them.

## Repository

| Setting | Value |
|---|---|
| Visibility | Public (personal account; see deviations) |
| Merge methods | Squash only (merge commits and rebase disabled) |
| Delete branch on merge | On |

## Ruleset `protect-main` (P1.2)

Target: the default branch. Enforcement: active. No bypass actors.

| Rule | Effect |
|---|---|
| `deletion` | `main` cannot be deleted |
| `non_fast_forward` | No force-push |
| `required_linear_history` | No merge commits |
| `pull_request` | PR required; stale approvals dismissed; conversations must be resolved; required approvals = 0 (solo) |

Required status checks are added in P6.7.

## Security (P1.3)

- Secret scanning: on
- Push protection: on
- Dependabot alerts: on
- Dependabot version updates: `.github/dependabot.yml` (Docker, GitHub Actions, Terraform)
- CODEOWNERS: `.github/CODEOWNERS`
- PR template: `.github/pull_request_template.md`

## Environments (P3.7)

| Environment | Protection | Variables |
|---|---|---|
| `dev` | None | `AZURE_CLIENT_ID` = client ID of `id-hello-gh-dev` |
| `prod` | Required reviewer: TheProgrammingPath (self-review allowed); deployment branches: `main` only | `AZURE_CLIENT_ID` = client ID of `id-hello-gh-prod` |

## Repository variables (P3.7)

`AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_CLIENT_ID_PLAN`.
These are identifiers, not secrets. The repository has no secrets.

## Deviations from the assignment (solo build)

| Assignment | This repo | Reason |
|---|---|---|
| 1 approval from a review buddy | 0 required approvals | Solo build; GitHub does not allow approving your own PR. PRs, linear history and (from P6.7) status checks still gate `main`. |
| Buddy is the required prod reviewer | Owner is the required prod reviewer, self-review allowed | Solo build; prod still waits for a deliberate approval. |
| CODEOWNERS lists owner and buddy | Owner only | Solo build. |
| Internal repository | Public repository | Internal visibility needs a GitHub Enterprise organization. No secrets are stored in the repo. |
