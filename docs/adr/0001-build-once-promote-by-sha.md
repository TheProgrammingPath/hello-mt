# ADR 0001: Build the image once and promote it by commit SHA

- Status: Accepted
- Date: 2026-11-14

## Context

The site runs in two environments, dev and prod. If each environment built its own image, prod could end up running something that was never tested in dev: a base image or package can change between two builds of the same commit. Image tags like `latest` make it worse, because you can't tell from the cluster which code is running.

## Decision

- CD builds the image **once**, in the `build-push` job, and pushes it to the shared registry as `crhellomt.azurecr.io/hello:<commit sha>`.
- `deploy-dev` deploys that exact tag and smoke-tests it; `/version.json` must report the same SHA.
- `deploy-prod` **never builds.** After approval, it checks that `hello:<sha>` already exists in ACR and deploys the same tag. If it's missing, the job fails.
- The prod identity has **AcrPull only**, so prod can't push or overwrite an image even by mistake.
- No `latest` tags anywhere.

## Consequences

- What reaches prod is byte-for-byte what passed dev's smoke test.
- The running version is always traceable: tag → commit → PR.
- Rollback is just redeploying an earlier SHA (`kubectl rollout undo`, or `scripts/deploy.sh prod <old sha>`).
- Trade-off: one shared registry serves both environments, so it's a shared dependency. A prod-only registry would add isolation, but needs an import step, which isn't worth it at this size.
- Trade-off: an image can go stale after it's built (new CVEs). This is covered by the weekly `scan-deployed` workflow; see PR #49 for a real case.