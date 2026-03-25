ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:1f144c77a9ecaaa132fc3037b4417d9f9fd0b7a50101c696af5cb186876aa2a3"
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
