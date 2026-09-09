ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:d2add786f2a5f43d1ab3ae54cd3193de929d0d12c378ff60891921f56f3e47ff"
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
