#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_DIR="${REPO_ROOT}/docker"

# Set Superset config path (can be overridden by existing env)
export SUPERSET_CONFIG_PATH="${SUPERSET_CONFIG_PATH:-${REPO_ROOT}/docker/superset/config/}"

echo "Using SUPERSET_CONFIG_PATH=${SUPERSET_CONFIG_PATH}"

echo "Starting FHIR data pipes stack..."
cd "${DOCKER_DIR}"
docker compose -f docker-compose-db.yaml \
  -f docker-compose-hapi.yaml \
  -f docker-compose-fhir-data-pipes.yaml \
  -f docker-compose-superset.yaml \
  -f docker-compose-superset-ports.yaml \
  up -d --build
