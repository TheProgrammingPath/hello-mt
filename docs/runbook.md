# Runbook: hello platform

Draft. Grows into the full runbook in Phase 9.

## Connect to a cluster

    az aks get-credentials --resource-group rg-hello-mt-dev --name aks-hello-mt-dev --overwrite-existing
    kubelogin convert-kubeconfig -l azurecli
    kubectl config current-context    # must print aks-hello-mt-dev, not docker-desktop
    kubectl get nodes

Local accounts are disabled: access is Entra ID plus Azure RBAC
(Azure Kubernetes Service RBAC Cluster Admin). A `Forbidden` right after a
role change usually clears after a few minutes.

## Stop and start an environment to save cost (P4.8)

Stop at the end of every working session:

    az aks stop  --resource-group rg-hello-mt-dev --name aks-hello-mt-dev
    az aks show  --resource-group rg-hello-mt-dev --name aks-hello-mt-dev --query powerState.code -o tsv   # Stopped

Start at the beginning of the next session (about 5 minutes):

    az aks start --resource-group rg-hello-mt-dev --name aks-hello-mt-dev

For prod, replace `dev` with `prod` in the resource group and cluster names.

### What still bills while stopped (measured on dev)

| Resource (in MC_rg-hello-mt-dev_aks-hello-mt-dev_eastus) | Bills while stopped |
|---|---|
| Standard load balancer `kubernetes` | Yes |
| Outbound public IP | Yes |
| App routing ingress public IP | Yes |
| Node scale set (0 instances), NSG, managed identities | No |

Running, dev autoscales to 2 x Standard_D2s_v5 for system pods. Stopped, only
the load balancer and two public IPs bill (roughly 90 percent cheaper).
The shared ACR (Basic) and state storage always bill a small amount.

## Infra changes when clusters are stopped

- Merging a PR that touches infra/envs or infra/modules runs terraform-apply: apply-dev, then plan-prod, then apply-prod after approval.
- Azure rejects updates to a stopped AKS cluster, so start the clusters before merging infra changes:
    az aks start -g rg-hello-mt-dev -n aks-hello-mt-dev
    az aks start -g rg-hello-mt-prod -n aks-hello-mt-prod
- Approve prod only after reading plan-prod's job summary. Stop both clusters afterwards.
- Prod ingress host: hello-prod.20.242.237.48.nip.io (the IP stays the same across stop and start).

## Troubleshooting: site down, pods unhealthy, or a restart alert email

Work top to bottom. Do not fix anything with kubectl edit; the repo is the source of truth.

1. Confirm which cluster you are talking to:

        kubectl config current-context

2. Look at the pods (STATUS, READY and RESTARTS columns):

        kubectl get pods -n hello -o wide

3. Read the events at the bottom of the unhealthy pod:

        kubectl describe pod <pod-name> -n hello

4. Read the logs of the container that crashed (the previous run, not the current one):

        kubectl logs <pod-name> -n hello --previous

5. Compare the image that is running with the image that should be running:

        kubectl get deployment hello -n hello -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
        kubectl rollout history deployment/hello -n hello

   Expected: crhellomt.azurecr.io/hello:<sha of the last good release>.

### What the symptom means

| Symptom | Likely cause | Fix |
|---|---|---|
| CrashLoopBackOff, RESTARTS climbing | The container exits on start: wrong image or a bad build | If the image is not crhellomt.azurecr.io/hello:<sha>, someone changed the cluster by hand (drift). Re-apply the repo: scripts/deploy.sh <env> <last-good-sha> |
| ImagePullBackOff | The tag is missing in ACR, or the kubelet lacks AcrPull | az acr repository show-tags -n crhellomt --repository hello; check the kubelet AcrPull role |
| Running but 0/1 READY | The readiness probe fails (describe shows "Readiness probe failed") | Fix the probe path in k8s/base and release through CD |
| Pending | Not enough node capacity | kubectl get nodes; check the autoscaler and vCPU quota |
| Request timeouts right after a deploy | Old pod stopped before the ingress drained it | Check the preStop hook is present in k8s/base/deployment.yaml |

Why the site usually stays up: the rollout uses maxUnavailable 0, so the old ReplicaSet keeps serving until new pods are Ready. A crash-looping new pod never becomes Ready, so it never receives traffic.

After the fix: kubectl get pods -n hello shows all pods Running and READY 1/1, curl http://<host>/version.json shows the expected SHA, and the restart alert resolves on its own within about 15 minutes.

## Troubleshooting: site down, pods unhealthy, or a restart alert email

Work top to bottom. Do not fix anything with kubectl edit; the repo is the source of truth.

1. Confirm which cluster you are talking to:

        kubectl config current-context

2. Look at the pods (STATUS, READY and RESTARTS columns):

        kubectl get pods -n hello -o wide

3. Read the events at the bottom of the unhealthy pod:

        kubectl describe pod <pod-name> -n hello

4. Read the logs of the container that crashed (the previous run, not the current one):

        kubectl logs <pod-name> -n hello --previous

5. Compare the image that is running with the image that should be running:

        kubectl get deployment hello -n hello -o jsonpath='{.spec.template.spec.containers[0].image}'; echo
        kubectl rollout history deployment/hello -n hello

   Expected: crhellomt.azurecr.io/hello:<sha of the last good release>.

### What the symptom means

| Symptom | Likely cause | Fix |
|---|---|---|
| CrashLoopBackOff, RESTARTS climbing | The container exits on start: wrong image or a bad build | If the image is not crhellomt.azurecr.io/hello:<sha>, someone changed the cluster by hand (drift). Re-apply the repo: scripts/deploy.sh <env> <last-good-sha> |
| ImagePullBackOff | The tag is missing in ACR, or the kubelet lacks AcrPull | az acr repository show-tags -n crhellomt --repository hello; check the kubelet AcrPull role |
| Running but 0/1 READY | The readiness probe fails (describe shows "Readiness probe failed") | Fix the probe path in k8s/base and release through CD |
| Pending | Not enough node capacity | kubectl get nodes; check the autoscaler and vCPU quota |
| Request timeouts right after a deploy | Old pod stopped before the ingress drained it | Check the preStop hook is present in k8s/base/deployment.yaml |

Why the site usually stays up: the rollout uses maxUnavailable 0, so the old ReplicaSet keeps serving until new pods are Ready. A crash-looping new pod never becomes Ready, so it never receives traffic.

After the fix: kubectl get pods -n hello shows all pods Running and READY 1/1, curl http://<host>/version.json shows the expected SHA, and the restart alert resolves on its own within about 15 minutes.
