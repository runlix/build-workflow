ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:aeb2e6aa676c55b201822f3b88c01c8a10b0a72ac1b2bdac8f5958e2eb2e71e9"
ARG VARIANT

FROM ${BASE_REF}

ARG BASE_REF
ARG VARIANT

COPY --chmod=0644 <<EOF /etc/build-info
{
  "arch": "amd64",
  "base_ref": "${BASE_REF}",
  "variant": "${VARIANT}"
}
EOF

CMD ["/etc/build-info"]
