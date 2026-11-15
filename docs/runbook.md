# Runbook: hello platform

How to operate the platform day to day. Every command is copy-pasteable; replace `<env>` with `dev` or `prod`. Run them in **Git Bash** from the repo root.

## 1. Service summary

| | dev | prod |
|---|---|---|
| URL | http://hello-dev.48.206.54.156.nip.io | http://hello-prod.20.242.237.48.nip.io |
| Version check | `curl -s <url>/version.json` | same |
| Cluster | `aks-hello-mt-dev` in `rg-hello-mt-dev` | `aks-hello-mt-prod` in `rg-hello-mt-prod` |
| Logs | Log Analytics `log-hello-mt-dev` | `log-hello-mt-prod` |
| Alert | `alert-restarts-hello-mt-dev` (Sev2, email) | `alert-restarts-hello-mt-prod` |
| Deploys | automatic after merge | after approval in the `prod` environment |

- **Owner:** Mohamed Toure (@TheProgrammingPath), who also receives the alert email.
- **Saved log queries:** [`docs/queries.kql`](queries.kql). Portal: Log Analytics workspace → **Logs**.
- **How it fits together:** [`docs/architecture.md`](architecture.md).

## 2. Connect to a cluster

```bash
az login                                   # if your session expired
az aks get-credentials -g rg-hello-mt-<env> -n aks-hello-mt-<env> --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
kubectl config current-context             # must print aks-hello-mt-<env>
kubectl get pods -n hello
```

Local accounts are disabled: access is Entra ID plus Azure RBAC. Always check the context before changing anything; `scripts/deploy.sh` refuses to run against the wrong one.

## 3. Deploy, and roll back

### Deploy (normal path: the pipeline)

1. Open a PR. The four required checks must pass.
2. Merge. `cd` builds `hello:<sha>` once and deploys it to dev, with a smoke test.
3. Approve prod:

   ```bash
   gh run list --workflow cd.yml --limit 1      # note the run ID
   gh run view <run-id> --web                   # Review deployments → prod → Approve and deploy
   ```

4. Check:

   ```bash
   curl -s http://hello-prod.20.242.237.48.nip.io/version.json   # shows the merged commit's SHA
   ```

If a deploy or smoke test fails, the pipeline runs `kubectl rollout undo` by itself and the job goes red. The previous version keeps serving.

### Roll back by hand (one revision)

```bash
az aks get-credentials -g rg-hello-mt-prod -n aks-hello-mt-prod --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
kubectl config current-context                               # aks-hello-mt-prod
kubectl rollout history deployment/hello -n hello            # see the revisions
kubectl rollout undo deployment/hello -n hello               # back one revision
kubectl rollout status deployment/hello -n hello --timeout 5m
curl -s http://hello-prod.20.242.237.48.nip.io/version.json  # shows the previous SHA
```

To go back to a **specific** release instead, redeploy its SHA (the image is already in ACR):

```bash
scripts/deploy.sh prod <good-sha>
git restore k8s/overlays/prod/kustomization.yaml
```

After a manual rollback the cluster no longer matches `main`. Fix the cause in a PR (or revert the bad PR) so the next pipeline run deploys a good version.

## 4. Scale by hand, and pause autoscaling

The HPA owns the replica count (dev 1-3, prod 2-6), so `kubectl scale` alone is undone within seconds. Pin the HPA instead:

```bash
kubectl patch hpa hello -n hello -p '{"spec":{"minReplicas":3,"maxReplicas":3}}'   # hold at exactly 3 pods
kubectl get hpa,pods -n hello
```

To **pause** autoscaling completely (for example during an investigation):

```bash
kubectl delete hpa hello -n hello
kubectl scale deployment hello -n hello --replicas=2
```

**Resume:** the next deploy re-applies the HPA from the repo. To restore it right away without changing the version:

```bash
SHA=$(kubectl get deployment hello -n hello -o jsonpath='{.spec.template.spec.containers[0].image}' | cut -d: -f2)
scripts/deploy.sh <env> "$SHA"
git restore k8s/overlays/<env>/kustomization.yaml
kubectl get hpa -n hello                    # back to 1-3 (dev) or 2-6 (prod)
```

## 5. Change the banner

The banner comes from each overlay's ConfigMap (`k8s/overlays/<env>/env.json`), not from the image.

```bash
git switch main && git pull
git switch -c banner/<short-name>
code k8s/overlays/dev/env.json            # edit "banner", save
git commit -am "chore(dev): change banner"
git push -u origin banner/<short-name>
gh pr create --fill
gh pr checks --watch
gh pr merge --squash --delete-branch
```

The ConfigMap name gets a new hash suffix, so Kubernetes rolls the pods. Check the page in the browser after `deploy-dev` finishes. For prod, edit `k8s/overlays/prod/env.json` and approve the prod deploy.

## 6. Stop and start an environment to save cost

Stop at the end of every working session:

```bash
az aks stop -g rg-hello-mt-<env> -n aks-hello-mt-<env> --no-wait
az aks show -g rg-hello-mt-<env> -n aks-hello-mt-<env> --query powerState.code -o tsv          # Stopped
```

Start at the beginning of the next session:

```bash
az aks start -g rg-hello-mt-<env> -n aks-hello-mt-<env> --no-wait
az aks show -g rg-hello-mt-<env> -n aks-hello-mt-<env> --query provisioningState -o tsv        # wait for Succeeded
kubectl --context aks-hello-mt-<env> get pods -n hello                                          # 1/1 Running
```

`powerState` says `Running` as soon as the start is accepted; wait for **`provisioningState` = `Succeeded`** and the pods to be Ready before deploying.

### What still bills while stopped (measured on dev)

| Resource (in MC_rg-hello-mt-dev_aks-hello-mt-dev_eastus) | Bills while stopped |
|---|---|
| Standard load balancer `kubernetes` | Yes |
| Outbound public IP | Yes |
| App routing ingress public IP | Yes |
| Node scale set (0 instances), NSG, managed identities | No |

Stopped, only the load balancer and two public IPs bill (roughly 90 percent cheaper). The shared ACR (Basic) and state storage always bill a small amount. The ingress IPs stay the same across stop and start.

### Merging while clusters are stopped

- App changes: `deploy-dev` fails (cluster unreachable). Start dev, then `gh run rerun <run-id> --failed`.
- Infra changes: Azure rejects updates to a stopped cluster. Start the clusters before merging anything under `infra/`.
- A waiting `deploy-prod` approval stays valid for 30 days; approve it once prod is running.

## 7. Rebuild an environment from zero

Prod is rebuilt only through the pipeline; nothing is applied to it from a laptop.

**If only dev or prod is gone** (bootstrap still exists):

```bash
gh workflow run terraform-apply.yml          # apply-dev, then plan-prod, then apply-prod after approval
gh run list --workflow terraform-apply.yml --limit 1
gh run view <run-id> --web                   # read plan-prod's summary, then approve prod
```

Then:

1. Get the new ingress IP (a new cluster gets a new one):

   ```bash
   az aks get-credentials -g rg-hello-mt-<env> -n aks-hello-mt-<env> --overwrite-existing
   kubelogin convert-kubeconfig -l azurecli
   kubectl get svc -n app-routing-system nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'; echo
   ```

2. If it changed, update the host in `k8s/overlays/<env>/kustomization.yaml` and `BASE_URL` in `.github/workflows/cd.yml` in a PR.
3. Deploy the app: merging that PR runs `cd`, or run `gh workflow run cd.yml`.
4. Confirm the alert email address again if Azure sends a new verification code.

**If everything is gone** (including bootstrap): run bootstrap from the laptop first.

```bash
cd infra/bootstrap
# The state storage doesn't exist yet: comment out the backend block in backend.tf
terraform init
terraform apply                              # creates RGs, ACR, state storage, GitHub identities
# Restore the backend block, then move the state into the new storage:
terraform init -migrate-state
terraform output github_client_ids           # copy into GitHub variables
```

Set the GitHub variables (IDs, not secrets), then follow "only dev or prod is gone" above:

```bash
gh variable set AZURE_CLIENT_ID_PLAN --body <plan client id>
gh variable set AZURE_CLIENT_ID --env dev  --body <dev client id>
gh variable set AZURE_CLIENT_ID --env prod --body <prod client id>
```

## 8. Troubleshooting

Work top to bottom. Don't fix anything with `kubectl edit`; the repo is the source of truth.

1. Confirm the cluster: `kubectl config current-context`
2. Pods (STATUS, READY, RESTARTS): `kubectl get pods -n hello -o wide`
3. Events for one pod: `kubectl describe pod <pod-name> -n hello`
4. Logs of the crashed run: `kubectl logs <pod-name> -n hello --previous`
5. What's running vs what should be:

   ```bash
   kubectl get deployment hello -n hello -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
   kubectl rollout history deployment/hello -n hello
   ```

### ImagePullBackOff

The tag isn't in ACR, or the nodes can't pull.

```bash
kubectl describe pod <pod-name> -n hello | tail -15                         # "not found" vs "unauthorized"
az acr repository show-tags -n crhellomt --repository hello --orderby time_desc --top 5 -o tsv
az aks check-acr -g rg-hello-mt-<env> -n aks-hello-mt-<env> --acr crhellomt.azurecr.io
```

Fix: deploy a SHA that exists (`scripts/deploy.sh <env> <sha>`), or restore the kubelet's AcrPull role through Terraform.

### CrashLoopBackOff

The container starts and exits. Use steps 3-5 above.

- Image isn't `crhellomt.azurecr.io/hello:<sha>`: someone changed the cluster by hand (drift). Re-apply the repo: `scripts/deploy.sh <env> <last-good-sha>`.
- Logs show an nginx error: fix it in a PR; the pipeline's smoke test catches it in dev.
- The site usually stays up: `maxUnavailable: 0` keeps the old pods serving, and a crash-looping pod never receives traffic. After more than 3 restarts in 30 minutes, the alert email arrives.

### Pending pods

No node has room, or nodes aren't ready.

```bash
kubectl describe pod <pod-name> -n hello | tail -10     # "Insufficient cpu" or "no nodes available"
kubectl get nodes
az aks show -g rg-hello-mt-<env> -n aks-hello-mt-<env> --query provisioningState -o tsv
```

- Just after a start: wait for `Succeeded` and the nodes to be Ready.
- Insufficient CPU: the autoscaler adds a node within a few minutes (dev max 3, prod max 4). If it can't, check vCPU quota: `az vm list-usage -l eastus -o table | grep -i "DSv5\|Total Regional"`.

### HPA shows `<unknown>`

```bash
kubectl get hpa -n hello
kubectl describe hpa hello -n hello | tail -10
kubectl top pods -n hello
```

- Right after a start or deploy: metrics-server needs a minute or two. Wait and check again.
- `kubectl top` fails: metrics-server isn't ready. `kubectl get pods -n kube-system | grep metrics-server`
- Still unknown: the pods must have CPU requests (`k8s/base/deployment.yaml` sets `cpu: 50m`).

### Stuck Terraform state lock

`Error acquiring the state lock` means another run holds the lock, or a cancelled run left it behind.

1. Make sure nothing is running: `gh run list --workflow terraform-apply.yml --limit 3` and `gh run list --workflow terraform.yml --limit 3`.
2. If nothing is running, release it with the lock ID from the error message:

   ```bash
   cd infra/envs/<env>
   terraform init
   terraform force-unlock <LOCK_ID>
   ```

   If that's not possible, break the lease on the state blob:

   ```bash
   az storage blob lease break --account-name sthellomtstate --container-name tfstate --blob-name <env>.tfstate --auth-mode login
   ```

3. Re-run the failed job: `gh run rerun <run-id> --failed`.

PR plans use `-lock=false`, so only applies take the lock.

### 403 / Forbidden after a role change

Azure role assignments take up to about 10 minutes to apply, and existing tokens keep the old permissions until they expire.

```bash
az role assignment list --assignee <principal-id> --all -o table     # is the role really there, at the right scope?
az logout && az login                                                # laptop: get a fresh token
az aks get-credentials -g rg-hello-mt-<env> -n aks-hello-mt-<env> --overwrite-existing
kubelogin convert-kubeconfig -l azurecli
```

- In GitHub Actions: wait a few minutes, then `gh run rerun <run-id> --failed` (each run gets a new OIDC token).
- Still 403: the role is missing or at the wrong scope. Add it in `infra/bootstrap/identities.tf` (pipeline identities) or `infra/modules/aks/main.tf` (cluster roles), never by hand in the portal.