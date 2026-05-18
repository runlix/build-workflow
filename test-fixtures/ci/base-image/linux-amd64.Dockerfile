ARG BASE_REF="gcr.io/distroless/base-debian12:latest-amd64@sha256:0b38c2ae0e6a2c1df28d8cada49a691b83d642286f21b4e49a598a2588612fb2"
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
