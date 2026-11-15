# ADR 0002: Public endpoints, protected by identity instead of network rules

- Status: Accepted
- Date: 2026-11-14

## Context

Two endpoints have to be reachable by GitHub Actions: the **AKS API server** (to deploy) and the **Terraform state storage account** (to plan and apply). Trivy's config scan flags both as CRITICAL:

- AZU-0041: the AKS API server has no authorized IP ranges.
- AZU-0012: the storage account allows access from public networks.

The usual fix is an IP allow-list or a private endpoint. But GitHub-hosted runners have **no fixed IP addresses**, so an allow-list would either block the pipeline or have to cover huge ranges. A private network would need self-hosted runners inside the VNet, which is more cost and upkeep than this project justifies.

## Decision

Keep both endpoints public and rely on **identity** as the control:

- **AKS:** local accounts disabled; every call needs an Entra ID token checked against Azure RBAC. Only the owner and that environment's GitHub identity hold Cluster Admin.
- **State storage:** shared keys disabled, Entra ID auth only, TLS 1.2 minimum, no public blob access, versioning and 7-day soft delete.
- **Pipeline identities:** OIDC only (no secrets), each trusting one exact subject. Prod's identity is only issued after a reviewer approves.
- The two Trivy findings are suppressed inline (`#trivy:ignore:AZU-0041`, `#trivy:ignore:AZU-0012`) with a comment pointing here, so the risk is visible next to the code.

## Consequences

- The pipeline works from any GitHub-hosted runner with no network setup.
- Anyone on the internet can reach the endpoints, but can't do anything without a valid Entra ID token and the right role.
- The risk that remains is a stolen or misused identity. It's reduced by short-lived OIDC tokens, per-environment scoping and the prod approval gate.
- Revisit this if the platform holds sensitive data or moves to self-hosted runners: then add private endpoints or authorized IP ranges.