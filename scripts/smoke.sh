#!/usr/bin/env bash
# Smoke test: scripts/smoke.sh <base-url> <expected-sha>
# Retries until SMOKE_TIMEOUT (default 120 s): the new version must be served,
# /healthz must return 200 and / must contain the page title. A real failure
# still fails after the timeout; a brief blip during a pod swap does not.
set -euo pipefail

BASE_URL="${1:?usage: smoke.sh <base-url> <sha>}"
SHA="${2:?usage: smoke.sh <base-url> <sha>}"
TIMEOUT="${SMOKE_TIMEOUT:-120}"
deadline=$(( $(date +%s) + TIMEOUT ))

echo "Smoke test: $BASE_URL (expecting version $SHA, timeout ${TIMEOUT}s)"
attempt=0
while true; do
  attempt=$((attempt + 1))
  problem=""
  version="$(curl -fsS --max-time 5 "$BASE_URL/version.json" 2>/dev/null || true)"
  if [[ "$version" != *"$SHA"* ]]; then
    problem="version.json does not report $SHA (got: ${version:-no response})"
  else
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$BASE_URL/healthz" || true)"
    if [[ "$code" != "200" ]]; then
      problem="/healthz returned ${code:-no response}, expected 200"
    else
      page="$(curl -fsS --max-time 5 "$BASE_URL/" 2>/dev/null || true)"
      if [[ "$page" != *"<title>hello-mt</title>"* ]]; then
        problem="/ does not contain <title>hello-mt</title>"
      fi
    fi
  fi
  if [[ -z "$problem" ]]; then
    echo "OK: version $SHA, /healthz 200, page title present (attempt $attempt)"
    exit 0
  fi
  if (( $(date +%s) >= deadline )); then
    echo "FAIL: $problem"
    exit 1
  fi
  echo "...attempt $attempt: $problem; retrying in 5s"
  sleep 5
done
