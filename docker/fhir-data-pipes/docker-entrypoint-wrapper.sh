#!/bin/bash
set -euo pipefail
trap 'echo "[wrapper] Error on line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

echo "[wrapper] Starting FHIR Data Pipes container..." >&2

# Run environment variable substitution
if ! /app/substitute-envs.sh; then
  echo "[wrapper] substitute-envs.sh failed with exit code $?" >&2
  exit 1
fi

# Optionally wait for FHIR server to be reachable (supports internal or external)
WAIT_FOR_FHIR=${WAIT_FOR_FHIR:-true}
WAIT_FOR_FHIR_TIMEOUT=${WAIT_FOR_FHIR_TIMEOUT:-300}
WAIT_FOR_FHIR_INTERVAL=${WAIT_FOR_FHIR_INTERVAL:-5}
WAIT_FOR_FHIR_INSECURE=${WAIT_FOR_FHIR_INSECURE:-true}
# New flag to enable/disable cert fetching
IMPORT_FHIR_CERT=${IMPORT_FHIR_CERT:-true}

resolve_fhir_url() {
  if [ -n "${FHIR_SERVER_URL:-}" ]; then
    echo "$FHIR_SERVER_URL"
    return 0
  fi
  if [ -f "/app/config/application.yaml" ]; then
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
  echo "[wrapper] Waiting for FHIR server: $md (timeout=${WAIT_FOR_FHIR_TIMEOUT}s, interval=${WAIT_FOR_FHIR_INTERVAL}s)"
  local deadline=$(( $(date +%s) + WAIT_FOR_FHIR_TIMEOUT ))
  local curl_opts=("--silent" "--show-error" "--fail" "--max-time" "5")
  if [ "$WAIT_FOR_FHIR_INSECURE" = "true" ]; then
    curl_opts+=("-k")
  fi
  while true; do
    if curl "${curl_opts[@]}" "$md" > /dev/null 2>&1; then
      echo "[wrapper] FHIR server is reachable."
      return 0
    fi
    if [ $(date +%s) -ge $deadline ]; then
      echo "[wrapper] Timed out waiting for FHIR server at $md" >&2
      return 1
    fi
    sleep "$WAIT_FOR_FHIR_INTERVAL"
  done
}

# --- Main Logic Start ---

if [ "$WAIT_FOR_FHIR" = "true" ]; then
  if url=$(resolve_fhir_url); then
    if ! wait_for_fhir "$url"; then
      echo "[wrapper] FHIR server not reachable; exiting." >&2
      exit 1
    fi
    
    # --- START: Fetch and Import FHIR Certificate ---
    if [ "$IMPORT_FHIR_CERT" = "true" ] && [[ "$url" == https* ]]; then
      echo "[wrapper] Attempting to fetch public key from FHIR server for Java Truststore..."
      
      # Extract host and port from URL
      # e.g., https://fhir.openelis.org:8443/fhir -> fhir.openelis.org:8443
      local host_port
      host_port=$(echo "$url" | sed -E 's|https?://([^/]+).*|\1|')
      
      # Handle cases where port is missing (default to 443 for https)
      if [[ "$host_port" != *:* ]]; then
        host_port="${host_port}:443"
      fi

      echo "[wrapper] Extracting cert from $host_port"
      if openssl s_client -showcerts -connect "$host_port" </dev/null 2>/dev/null | openssl x509 -outform PEM > /tmp/fhir_server.crt; then
        echo "[wrapper] Certificate fetched. Importing into $JAVA_HOME/lib/security/cacerts..."
        # Note: Using -noprompt and -storepass changeit (default Java password)
        if keytool -import -alias fhir_server_auto -keystore "$JAVA_HOME/lib/security/cacerts" -file /tmp/fhir_server.crt -storepass changeit -noprompt; then
          echo "[wrapper] Successfully imported FHIR server certificate."
        else
          echo "[wrapper] WARNING: Failed to import certificate into Truststore." >&2
        fi
      else
        echo "[wrapper] WARNING: Could not fetch certificate from $host_port. Java may throw SSL errors." >&2
      fi
    fi
    # --- END: Fetch and Import FHIR Certificate ---

  else
    echo "[wrapper] Could not resolve FHIR_SERVER_URL; skipping wait/cert import." >&2
  fi
else
  echo "[wrapper] WAIT_FOR_FHIR is disabled; continuing without wait." >&2
fi

# Now execute the original entrypoint to preserve the exact startup sequence
echo "[wrapper] Executing original /docker-entrypoint.sh" >&2
exec /docker-entrypoint.sh "$@"