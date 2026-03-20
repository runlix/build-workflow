ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:d5f7dca58e3db53d1de502bd1a747ecb1110cf6b0773af129f951ee11e2e3ed4"
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
