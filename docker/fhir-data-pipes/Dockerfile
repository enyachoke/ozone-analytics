ARG FHIR_PIPELINES_VERSION=latest
FROM us-docker.pkg.dev/cloud-build-fhir/fhir-analytics/main:${FHIR_PIPELINES_VERSION}

USER root
RUN apt-get update && \
	apt-get install -y gettext-base curl ca-certificates && \
	rm -rf /var/lib/apt/lists/*
COPY ./config /app/config-templates

COPY --chmod=0755 ./substitute-envs.sh /app/substitute-envs.sh
COPY --chmod=0755 ./entrypoint.sh /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]
