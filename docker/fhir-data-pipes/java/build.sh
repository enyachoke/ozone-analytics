#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Compiling TrustAllAgent.java..."
javac TrustAllAgent.java

echo "Building agent JAR at ../trust-all-agent.jar..."
jar cfm ../trust-all-agent.jar manifest.mf TrustAllAgent.class

echo "Done. JAR created at docker/fhir-data-pipes/trust-all-agent.jar"

