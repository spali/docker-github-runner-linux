#!/usr/bin/env bash
# Registers the runner and runs it. Environment:
#   RUNNER_URL    required: https://github.com/OWNER/REPO, or https://github.com/ORG
#   ACCESS_TOKEN  PAT that fetches a registration token on every start (see .env.example)
#   RUNNER_TOKEN  alternative: registration token from the settings page (valid 1 h, needs EPHEMERAL=false)
#   RUNNER_NAME   default: container hostname
#   RUNNER_LABELS extra labels, comma separated (self-hosted, Linux, X64/ARM64 are always set)
#   RUNNER_GROUP  runner group (organizations only)
#   EPHEMERAL     true (default): one job per registration, clean state for every job
set -euo pipefail

: "${RUNNER_URL:?RUNNER_URL is required}"
EPHEMERAL=${EPHEMERAL:-true}
# Keep the tokens out of the environment the jobs inherit.
pat=${ACCESS_TOKEN:-}
reg=${RUNNER_TOKEN:-}
unset ACCESS_TOKEN RUNNER_TOKEN
cd /home/runner

api_token() { # $1: registration-token | remove-token
  local host path api
  host=${RUNNER_URL#https://}
  path=${host#*/}
  host=${host%%/*}
  path=${path%/}
  [[ $host == github.com ]] && api=https://api.github.com || api=https://$host/api/v3
  [[ $path == */* ]] && path=repos/$path || path=orgs/$path
  curl -fsSL -X POST -H "Authorization: Bearer $pat" \
    -H "Accept: application/vnd.github+json" "$api/$path/actions/runners/$1" | jq -er .token
}

if [[ $EPHEMERAL == true ]]; then
  [[ -n $pat ]] || { echo "error: EPHEMERAL=true needs ACCESS_TOKEN" >&2; exit 1; }
  # A restarted container keeps its filesystem: start from scratch every time.
  rm -rf .runner .credentials .credentials_rsaparams _work
fi

if [[ ! -f .runner ]]; then
  [[ -n $pat ]] && reg=$(api_token registration-token)
  [[ -n $reg ]] || { echo "error: ACCESS_TOKEN or RUNNER_TOKEN is required" >&2; exit 1; }
  args=(--unattended --replace --url "$RUNNER_URL" --token "$reg"
    --name "${RUNNER_NAME:-$(hostname)}" --work _work --disableupdate)
  [[ -n ${RUNNER_LABELS:-} ]] && args+=(--labels "$RUNNER_LABELS")
  [[ -n ${RUNNER_GROUP:-} ]] && args+=(--runnergroup "$RUNNER_GROUP")
  [[ $EPHEMERAL == true ]] && args+=(--ephemeral)
  ./config.sh "${args[@]}"
fi

deregister() {
  # An idle ephemeral runner stopped by docker would stay registered offline.
  if [[ $EPHEMERAL == true && -f .runner && -n $pat ]]; then
    ./config.sh remove --token "$(api_token remove-token)" || true
  fi
}

# RUNNER_MANUALLY_TRAP_SIG=1 (base image): forward the stop signal to the runner.
./run.sh &
pid=$!
trap 'kill -TERM $pid 2>/dev/null; wait $pid; deregister; exit 0' TERM INT
wait $pid
