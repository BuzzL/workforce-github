#!/usr/bin/env bash
# Every job of live-github.yml must set TF_VAR_require_app_auth to "true", and the workflow
# must never name a token: the tests prove the variable's validation, this proves CI uses it.
set -euo pipefail
cd "$(dirname "$0")/.."

f=.github/workflows/live-github.yml
jobs=$(awk '/^jobs:/ {inj = 1; next} inj && /^  [a-z][a-z-]*:[[:space:]]*$/ {n++} END {print n + 0}' "$f")
guards=$(grep -cE '^      TF_VAR_require_app_auth: "true"$' "$f" || true)

if [ "$jobs" -eq 0 ] || [ "$jobs" -ne "$guards" ]; then
  echo "$f: $jobs jobs but $guards set TF_VAR_require_app_auth: \"true\" (every job must)"
  exit 1
fi
if grep -nE 'GITHUB_TOKEN|GH_TOKEN|secrets\.GITHUB_TOKEN' "$f"; then
  echo "$f: CI must authenticate as the App, never with a token"
  exit 1
fi
echo "$f: $jobs jobs, all require the App"
