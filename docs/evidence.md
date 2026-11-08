# Evidence

Proof for each step's "Done when". Newest phases at the bottom.

## P1.2: main is protected

A direct push to main is rejected:

    remote: error: GH013: Repository rule violations found for refs/heads/main.
    remote: - Changes must be made through a pull request.
     ! [remote rejected] main -> main (push declined due to repository rule violations)

What this proves: nobody, including the owner, can push to main without a pull request.

## CP1: site running locally in its container, main protected

    $ scripts/smoke.sh http://localhost:8081 1b82f9f518b1c7ae5996cb4983afc6b365eda10a
    OK: /version.json reports 1b82f9f518b1c7ae5996cb4983afc6b365eda10a
    OK: /healthz returned 200
    OK: / contains the page title
    PASS: smoke test succeeded

    $ gh api repos/TheProgrammingPath/hello-mt/rules/branches/main --jq '.[].type'
    deletion
    non_fast_forward
    required_linear_history
    pull_request

Image: 27.9 MB, user 101 (non-root), amd64, Trivy 0 HIGH/CRITICAL, hadolint clean.

## P3.8: GitHub reaches Azure with OIDC (no secrets)

Run: https://github.com/TheProgrammingPath/hello-mt/actions/runs/41325179691

    Azure login with OIDC (no secrets): success
    "name": "rg-hello-mt-dev"
    OK: the dev identity cannot read rg-hello-mt-prod (least privilege)

What this proves: GitHub Actions logs in to Azure with a short-lived token and no stored
secret, and the dev identity cannot touch prod.

## P5.8: first deploy to dev passes the smoke test

    $ scripts/deploy.sh dev 1b82f9f518b1c7ae5996cb4983afc6b365eda10a
    namespace/hello created
    configmap/hello-config-48bdt9h4c7 created
    service/hello created
    deployment.apps/hello created
    horizontalpodautoscaler.autoscaling/hello created
    ingress.networking.k8s.io/hello created
    deployment "hello" successfully rolled out

    $ scripts/smoke.sh http://hello-dev.48.206.54.156.nip.io 1b82f9f518b1c7ae5996cb4983afc6b365eda10a
    PASS: smoke test succeeded

## P5.9: the HPA scales under load

Load: `hey -z 3m -c 50 http://hello-dev.48.206.54.156.nip.io/`

    Requests/sec: 1437.6331
    Average:      0.0348 secs
    Status code distribution:
      [200] 85116 responses

HPA events:

    Normal  SuccessfulRescale  New size: 2; reason: cpu resource utilization (percentage of request) above target
    Normal  SuccessfulRescale  New size: 3; reason: cpu resource utilization (percentage of request) above target

Pods after scale-out:

    pod/hello-5fc64bf64d-hjpp4   1/1   Running
    pod/hello-5fc64bf64d-mlwj9   1/1   Running
    pod/hello-5fc64bf64d-t2crf   1/1   Running

Scale-down to 1: to be captured after the next cluster start.

Note: the earlier `FailedGetResourceMetric` warnings came from metrics-server
starting up right after `az aks start` (the HPA showed `<unknown>`); they
stopped once metrics were available.

## P5.10: manifests validate offline

    $ kubectl kustomize k8s/overlays/dev | kubeconform -strict -summary
    Summary: 6 resources found parsing stdin - Valid: 6, Invalid: 0, Errors: 0, Skipped: 0
    $ kubectl kustomize k8s/overlays/prod | kubeconform -strict -summary
    Summary: 7 resources found parsing stdin - Valid: 7, Invalid: 0, Errors: 0, Skipped: 0
    ## Phase 6: CI (PR #7)

- **P6.1:** `.github/workflows/ci.yml` runs on every PR to main: lint (htmlhint, hadolint, kubeconform on dev+prod), then build-test-scan (build without pushing, run read-only, smoke test, Trivy CRITICAL). `permissions: contents: read`, concurrency cancels stale runs. `actionlint`: clean. First run: both green (run 42345407874).
- **P6.2 deliberate lint failure:** added `<DIV>broken on purpose` to index.html. lint ✗ (`tagname-lowercase`, `tag-pair`), build-test-scan **skipped** via `needs: lint` (run 42346450952). Screenshot: p6.2-lint-fail.png. Reverted.
- **P6.3 deliberate smoke failure:** renamed `/healthz` to `/healthz-broken` in nginx.conf. build-test-scan ✗: `OK: /version.json reports <sha>` then `FAIL: /healthz returned 404, expected 200` (run 42348271489). Reverted.
- **Build cache:** revert run 42347303208 reused 3 layers from the gha cache (`#14 CACHED`, `#15 CACHED`, `#17 CACHED`). Wall-clock time didn't drop (32 s → 51 s) because this job is dominated by runner startup and the Trivy image pull, not the tiny build. Caching pays off on heavier builds.
- **P6.4 secret scan:** `secret-scan` job runs gitleaks v8.28.0 over only the PR's commits (`--log-opts=base..head`, `fetch-depth: 0`), output `--redact`ed, SHAs passed through `env:` to avoid script injection. PR #8: `2 commits scanned, no leaks found`; runs in parallel with lint (3 checks per PR).
- **P6.5 Terraform PR plans (PR #9):** `terraform.yml` runs on PRs touching infra: trivy-config job, then a dev/prod matrix doing fmt -check, init, validate, tflint, plan as `id-hello-gh-plan` via OIDC (no secrets; `id-token: write`; plan identity is Reader only; `-lock=false`). Plans posted to the job summary. Tag test (`repo = "hello-mt"` added to both envs): dev `Plan: 0 to add, 3 to change, 0 to destroy`, prod `Plan: 8 to add, 0 to change, 0 to destroy`. Screenshot: p6.5-tag-plans.png.
- **Trivy config findings accepted:** AZU-0012 (state storage reachable from public networks) and AZU-0041 (AKS API not IP-restricted). Reason: GitHub-hosted runners have no fixed IPs. Compensating controls: shared keys disabled and Entra-only auth on state; Entra ID + Azure RBAC with local accounts disabled on AKS. Inline `#trivy:ignore` with the reason next to the code; ADR in Phase 9.
- **Bug found and fixed: CI was green while Terraform failed.** `terraform plan | tee plan.txt` ran under GitHub's default `bash -e` (no `pipefail`), so tee's exit code hid plan errors. Spotted because CI planned 7 resources for prod and the local run planned 8 (`kubelet_acr_pull` missing). Root cause: the plan identity got 403 on `registries/read` (ACR in the shared RG) and on `listClusterUserCredential` (azurerm refreshes the AKS kubeconfig). Fixes: `shell: bash` (adds `-o pipefail`) in both workflows; plan identity granted Reader on the ACR only and Azure Kubernetes Service Cluster User Role on the dev/prod RGs only (kubeconfig stub; no in-cluster RBAC, local accounts disabled). After: dev `0 to add, 3 to change`, prod `8 to add`, no errors.

## P6.6 to P6.8: apply on main and required checks

- **P6.6 apply on main (PR #22, run 42404244873):** terraform-apply.yml ran apply-dev (dev identity, `environment: dev`) in 3m18s, then plan-prod (plan identity, saved plan uploaded as a 1-day artifact) showing `Plan: 8 to add`, then apply-prod paused for the prod environment's required reviewer. Approved by TheProgrammingPath with a review comment after reading the plan; the saved plan was applied. Prod verified: Succeeded/Running, Kubernetes 1.36.5, 2 nodes in 10.20.0.0/22 across zones, ingress IP 20.242.237.48. Prod apply never run by hand. Screenshot: p6.6-approved-apply.png. Both clusters stopped afterwards.
- **P5.9 scale-down:** dev HPA back at 1 replica, cpu 2%/50%, after the load test. Screenshot: p5.9-hpa-scaled-down.png.
- **P6.7/P6.8 required checks:** ruleset `protect-main` (active, bypass list empty) requires a PR, linear history, no force-push or deletion, and status checks `lint`, `build-test-scan`, `secret-scan`, `plan-ok`. `terraform.yml` runs on every PR: a `changes` job decides whether infra was touched, `trivy-config` and `plan` run only if so, and `plan-ok` always reports (passes only if every infra job succeeded or was skipped). Screenshot: p6.8-required-checks.png.
- **P6.8 proof (PR #28):** `/healthz` broken on purpose; `build-test-scan` failed; `gh pr merge` refused with "the base branch policy prohibits the merge"; `mergeStateStatus` = BLOCKED. Closed unmerged. Screenshot: p6.8-merge-blocked.png.
- **Lesson learned:** test PRs #24 and #26 merged because the ruleset change was never saved (saving needs a sudo-mode confirmation that was missed). Caught by verifying through the API (`rules/branches/main` had no `required_status_checks`), not by trusting the settings page. Fixed forward with PR #27 under enforcement. Takeaway: verify a security control is actually enforced before relying on it.
