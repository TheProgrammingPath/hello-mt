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
