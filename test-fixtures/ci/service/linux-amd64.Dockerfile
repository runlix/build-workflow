ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:aeb2e6aa676c55b201822f3b88c01c8a10b0a72ac1b2bdac8f5958e2eb2e71e9"
ARG APP_VERSION
ARG APP_PORT
ARG VARIANT

FROM ${BASE_REF}

ARG BASE_REF
ARG APP_VERSION
ARG APP_PORT
ARG VARIANT

COPY --chmod=0644 <<EOF /app/metadata.json
{
  "app_version": "${APP_VERSION}",
  "base_ref": "${BASE_REF}",
  "port": "${APP_PORT}",
  "variant": "${VARIANT}"
}
EOF

EXPOSE 8080
CMD ["/app/metadata.json"]
