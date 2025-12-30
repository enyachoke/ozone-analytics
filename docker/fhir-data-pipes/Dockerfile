ARG FHIR_PIPELINES_VERSION=latest
FROM us-docker.pkg.dev/cloud-build-fhir/fhir-analytics/main:${FHIR_PIPELINES_VERSION}

USER root
RUN apt-get update && \
	apt-get install -y gettext-base curl ca-certificates && \
	rm -rf /var/lib/apt/lists/*

VOLUME [ "/views" ]

# Save the original entrypoint from the base image
RUN cp /docker-entrypoint.sh /docker-entrypoint-original.sh

# Copy config templates for runtime substitution
COPY ./config /app/config-templates

# Copy the substitution and wrapper scripts
COPY --chmod=0755 ./substitute-envs.sh /app/substitute-envs.sh
COPY --chmod=0755 ./docker-entrypoint-wrapper.sh /docker-entrypoint-wrapper.sh
ENTRYPOINT ["/docker-entrypoint-wrapper.sh"]
