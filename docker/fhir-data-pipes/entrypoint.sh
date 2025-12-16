#!/bin/bash

set -euo pipefail
trap 'echo "[entrypoint] Error on line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

# Run environment variable substitution
if ! /app/substitute-envs.sh; then
  echo "[entrypoint] substitute-envs.sh failed with exit code $?" >&2
  exit 1
fi

# Optionally wait for FHIR server to be reachable (supports internal or external)
WAIT_FOR_FHIR=${WAIT_FOR_FHIR:-true}
WAIT_FOR_FHIR_TIMEOUT=${WAIT_FOR_FHIR_TIMEOUT:-300}
WAIT_FOR_FHIR_INTERVAL=${WAIT_FOR_FHIR_INTERVAL:-5}
WAIT_FOR_FHIR_INSECURE=${WAIT_FOR_FHIR_INSECURE:-true}

resolve_fhir_url() {
  if [ -n "${FHIR_SERVER_URL:-}" ]; then
    echo "$FHIR_SERVER_URL"
    return 0
  fi
  if [ -f "/app/config/application.yaml" ]; then
    # Read fhirServerUrl: value (handles quoted or unquoted)
    local url
    url=$(grep -E '^\s*fhirServerUrl\s*:\s*' /app/config/application.yaml | sed -E 's/^\s*fhirServerUrl\s*:\s*\"?([^\"]*)\"?.*$/\1/' | tail -n1 || true)
    if [ -n "$url" ]; then
      echo "$url"
      return 0
    fi
  fi
  return 1
}

append_metadata() {
  local base="$1"
  if echo "$base" | grep -qE '/metadata($|[/?])'; then
    echo "$base"
    return 0
  fi
  if echo "$base" | grep -qE '/$'; then
    echo "${base}metadata"
  else
    echo "${base}/metadata"
  fi
}

wait_for_fhir() {
  local url="$1"
  local md
  md=$(append_metadata "$url")
  echo "[entrypoint] Waiting for FHIR server: $md (timeout=${WAIT_FOR_FHIR_TIMEOUT}s, interval=${WAIT_FOR_FHIR_INTERVAL}s)"
  local deadline=$(( $(date +%s) + WAIT_FOR_FHIR_TIMEOUT ))
  local curl_opts=("--silent" "--show-error" "--fail" "--max-time" "5")
  if [ "$WAIT_FOR_FHIR_INSECURE" = "true" ]; then
    curl_opts+=("-k")
  fi
  while true; do
    if curl "${curl_opts[@]}" "$md" > /dev/null 2>&1; then
      echo "[entrypoint] FHIR server is reachable."
      return 0
    fi
    if [ $(date +%s) -ge $deadline ]; then
      echo "[entrypoint] Timed out waiting for FHIR server at $md" >&2
      return 1
    fi
    sleep "$WAIT_FOR_FHIR_INTERVAL"
  done
}

if [ "$WAIT_FOR_FHIR" = "true" ]; then
  if url=$(resolve_fhir_url); then
    if ! wait_for_fhir "$url"; then
      echo "[entrypoint] FHIR server not reachable; exiting." >&2
      exit 1
    fi
  else
    echo "[entrypoint] Could not resolve FHIR_SERVER_URL; skipping wait." >&2
  fi
else
  echo "[entrypoint] WAIT_FOR_FHIR is disabled; continuing without wait." >&2
fi

if [ -f "/docker-entrypoint.sh" ]; then
  echo "[entrypoint] Executing bundled /docker-entrypoint.sh $@"
  exec /docker-entrypoint.sh "$@"
fi

# Fallback: try controller-cli if available
if command -v controller-cli >/dev/null 2>&1; then
  echo "Starting controller via controller-cli..."
  # If a CMD was provided, pass it through; otherwise, start the web app
  if [ $# -gt 0 ]; then
    exec controller-cli "$@"
  else
    exec controller-cli web --config /app/config/application.yaml
  fi
fi

# Fallback: run bundled JAR directly if present
if [ -f "/app/controller-bundled.jar" ]; then
  echo "Starting controller via Java JAR..."
  exec java ${JAVA_OPTS:-} -jar /app/controller-bundled.jar
fi

echo "No known startup mechanism found. Exiting."
exit 1
