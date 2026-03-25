ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:1f144c77a9ecaaa132fc3037b4417d9f9fd0b7a50101c696af5cb186876aa2a3"
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
