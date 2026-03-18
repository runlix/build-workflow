ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST
ARG APP_VERSION
ARG APP_PORT
ARG VARIANT

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST
ARG APP_VERSION
ARG APP_PORT
ARG VARIANT

COPY --chmod=0644 <<EOF /app/metadata.json
{
  "app_version": "${APP_VERSION}",
  "base_image": "${BASE_IMAGE}",
  "base_tag": "${BASE_TAG}",
  "base_digest": "${BASE_DIGEST}",
  "port": "${APP_PORT}",
  "variant": "${VARIANT}"
}
EOF

EXPOSE 8080
CMD ["/app/metadata.json"]
