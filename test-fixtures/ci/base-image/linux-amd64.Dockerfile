ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:d5f7dca58e3db53d1de502bd1a747ecb1110cf6b0773af129f951ee11e2e3ed4"
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
