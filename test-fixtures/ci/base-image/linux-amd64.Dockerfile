ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:d2add786f2a5f43d1ab3ae54cd3193de929d0d12c378ff60891921f56f3e47ff"
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
