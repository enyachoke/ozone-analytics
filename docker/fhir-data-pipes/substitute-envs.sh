#!/bin/bash

set -euo pipefail
trap 'echo "[substitute-envs] Error on line ${LINENO}: ${BASH_COMMAND}" >&2' ERR

echo "[substitute-envs] Substituting environment variables in configuration files..." >&2

# Ensure destination dirs exist
mkdir -p /app/config

# Process all YAML and JSON files in config-templates with simple envsubst
echo "[substitute-envs] Processing config templates..." >&2
for template_file in /app/config-templates/*.yaml /app/config-templates/*.json; do
    if [ -f "$template_file" ]; then
        filename=$(basename "$template_file")
        echo "[substitute-envs] Processing $filename..." >&2
        if ! envsubst < "$template_file" > "/app/config/$filename"; then
            echo "[substitute-envs] envsubst failed for $filename" >&2
            return 1
        fi
    fi
done

# Process view files if they exist
if [ -d "/app/config-templates/views" ]; then
    echo "[substitute-envs] Processing view templates..." >&2
    mkdir -p /app/config/views
    for template_file in /app/config-templates/views/*.sql; do
        if [ -f "$template_file" ]; then
            filename=$(basename "$template_file")
            echo "[substitute-envs] Processing views/$filename..." >&2
            if ! envsubst < "$template_file" > "/app/config/views/$filename"; then
                echo "[substitute-envs] envsubst failed for views/$filename" >&2
                return 1
            fi
        fi
    done
fi

echo "[substitute-envs] Environment variable substitution complete." >&2

