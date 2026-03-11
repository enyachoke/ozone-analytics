#!/bin/bash
set -euo pipefail
trap 'echo "[wrapper] Error on line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

echo "[wrapper] Starting FHIR Data Pipes container..." >&2

# ... (substitute-envs logic remains the same) ...

# 1. Resolve URLs
# FHIR_SERVER_URL: The main one used for the wait loop and the application
# FHIR_SERVER_URL_TLS: The public one used ONLY to pull the certificate
FHIR_SERVER_URL=$(resolve_fhir_url)
FHIR_SERVER_URL_TLS=${FHIR_SERVER_URL_TLS:-""}

# 2. Handle the "Wait for FHIR" loop using the primary URL
# If this is set to the internal HTTP port (e.g. 8080), curl won't get stuck on mTLS
if [ "$WAIT_FOR_FHIR" = "true" ] && [ -n "$FHIR_SERVER_URL" ]; then
    if ! wait_for_fhir "$FHIR_SERVER_URL"; then
      echo "[wrapper] FHIR server not reachable; exiting." >&2
      exit 1
    fi
fi

# 3. Fetch and Import the Certificate using the TLS URL
if [ "$IMPORT_FHIR_CERT" = "true" ] && [ -n "$FHIR_SERVER_URL_TLS" ]; then
    echo "[wrapper] Using FHIR_SERVER_URL_TLS to fetch public key..."
    
    # Extract host and port from the TLS-specific URL
    local tls_host_port
    tls_host_port=$(echo "$FHIR_SERVER_URL_TLS" | sed -E 's|https?://([^/]+).*|\1|')
    
    # Ensure port 443 if not specified
    [[ "$tls_host_port" != *:* ]] && tls_host_port="${tls_host_port}:443"

    echo "[wrapper] Extracting cert from $tls_host_port"
    # openssl s_client works even with mTLS because it grabs the server cert 
    # during the handshake before the server terminates the connection for missing client certs.
    if openssl s_client -showcerts -connect "$tls_host_port" </dev/null 2>/dev/null | openssl x509 -outform PEM > /tmp/fhir_server.crt; then
        echo "[wrapper] Certificate fetched. Importing into Java Truststore..."
        keytool -import -alias fhir_server_auto -keystore "$JAVA_HOME/lib/security/cacerts" \
                -file /tmp/fhir_server.crt -storepass changeit -noprompt
        echo "[wrapper] Successfully imported certificate."
    else
        echo "[wrapper] WARNING: Could not fetch certificate from $tls_host_port" >&2
    fi
fi

echo "[wrapper] Executing original /docker-entrypoint.sh" >&2
exec /docker-entrypoint.sh "$@"