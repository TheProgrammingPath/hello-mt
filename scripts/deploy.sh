#!/usr/bin/env bash
# Deploys one image (by commit SHA) to one environment.
# Usage: scripts/deploy.sh <dev|prod> <sha>
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <dev|prod> <sha>" >&2
  exit 2
fi

ENV="$1"
SHA="$2"
case "$ENV" in
  dev|prod) ;;
  *) echo "environment must be dev or prod" >&2; exit 2 ;;
esac

REGISTRY="${REGISTRY:-crhellomt.azurecr.io}"
OVERLAY="k8s/overlays/${ENV}"

# Safety: refuse to deploy if kubectl points at the wrong cluster.
CONTEXT="$(kubectl config current-context)"
if [ "$CONTEXT" != "aks-hello-mt-${ENV}" ]; then
  echo "kubectl context is '${CONTEXT}', expected 'aks-hello-mt-${ENV}'" >&2
  exit 1
fi

echo "Deploying ${REGISTRY}/hello:${SHA} to ${ENV}"

# 1. Point the overlay at this exact image.
(cd "$OVERLAY" && kustomize edit set image "hello=${REGISTRY}/hello:${SHA}")

# 2. Apply everything the overlay builds.
kubectl apply -k "$OVERLAY"

# 3. Wait until the new pods are Ready (fails after 5 minutes).
kubectl rollout status deployment/hello -n hello --timeout 5m