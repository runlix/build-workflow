ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:0b38c2ae0e6a2c1df28d8cada49a691b83d642286f21b4e49a598a2588612fb2"
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
