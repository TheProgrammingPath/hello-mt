#!/usr/bin/env bash
# Smoke test for the hello site.
# Usage: scripts/smoke.sh <base-url> <expected-sha>
# Waits up to SMOKE_TIMEOUT seconds (default 120) for /version.json to
# report the expected SHA, then checks /healthz and the page title.
# Exits non-zero on any failure. Used locally, in CI (P6.3) and in CD (P7.1).
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <base-url> <expected-sha>" >&2
  exit 2
fi

BASE_URL="${1%/}"
EXPECTED_SHA="$2"
TITLE="<title>hello-mt</title>"
TIMEOUT_SECONDS="${SMOKE_TIMEOUT:-120}"
INTERVAL_SECONDS=5

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

echo "Smoke test: ${BASE_URL} (expecting version ${EXPECTED_SHA})"

# 1. Wait until the expected version is being served.
deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
while true; do
  version_json="$(curl -fsS --max-time 5 "${BASE_URL}/version.json" 2>/dev/null || true)"
  if [[ "$version_json" == *"\"version\":\"${EXPECTED_SHA}\""* ]]; then
    echo "OK: /version.json reports ${EXPECTED_SHA}"
    break
  fi
  if [ "$(date +%s)" -ge "$deadline" ]; then
    fail "/version.json did not report ${EXPECTED_SHA} within ${TIMEOUT_SECONDS}s (last response: ${version_json:-none})"
  fi
  echo "...waiting (got: ${version_json:-no response}); retrying in ${INTERVAL_SECONDS}s"
  sleep "$INTERVAL_SECONDS"
done

# 2. Health endpoint must return 200.
status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "${BASE_URL}/healthz" || true)"
[ "$status" = "200" ] || fail "/healthz returned ${status:-no response}, expected 200"
echo "OK: /healthz returned 200"

# 3. The page must contain its title.
page="$(curl -fsS --max-time 5 "${BASE_URL}/" || true)"
[[ "$page" == *"$TITLE"* ]] || fail "/ does not contain ${TITLE}"
echo "OK: / contains the page title"

echo "PASS: smoke test succeeded"
