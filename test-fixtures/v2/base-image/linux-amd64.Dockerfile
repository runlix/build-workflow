ARG BASE_IMAGE
ARG BASE_TAG
ARG BASE_DIGEST
ARG VARIANT

FROM ${BASE_IMAGE}:${BASE_TAG}@${BASE_DIGEST}

COPY --chmod=0644 <<EOF /etc/build-info
{
  "arch": "amd64",
  "base_image": "${BASE_IMAGE}",
  "base_tag": "${BASE_TAG}",
  "base_digest": "${BASE_DIGEST}",
  "variant": "${VARIANT}"
}
EOF

CMD ["/etc/build-info"]
