FROM python:3.14-slim-trixie

# renovate: datasource=deb depName=bash suite=trixie
ARG BASH_VERSION=5.2.37-2+b8
# renovate: datasource=deb depName=ca-certificates suite=trixie
ARG CA_CERTIFICATES_VERSION=20250419
# renovate: datasource=deb depName=git suite=trixie
ARG GIT_VERSION=1:2.47.3-0+deb13u1
# renovate: datasource=deb depName=jq suite=trixie
ARG JQ_VERSION=1.7.1-6+deb13u1

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    bash="${BASH_VERSION}" \
    ca-certificates="${CA_CERTIFICATES_VERSION}" \
    git="${GIT_VERSION}" \
    jq="${JQ_VERSION}" \
  && rm -rf /var/lib/apt/lists/*

COPY tools/ci /opt/build-workflow/tools/ci
COPY schema /opt/build-workflow/schema

RUN python -m pip install --no-cache-dir --root-user-action=ignore -r /opt/build-workflow/tools/ci/requirements.txt

ENV PATH="/opt/build-workflow/tools/ci/bin:${PATH}"

ENTRYPOINT ["/opt/build-workflow/tools/ci/bin/build-workflow-ci"]
