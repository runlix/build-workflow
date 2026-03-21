FROM python:3.12-slim

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends bash ca-certificates git jq \
  && rm -rf /var/lib/apt/lists/*

COPY tools/ci /opt/build-workflow/tools/ci
COPY schema /opt/build-workflow/schema

RUN python -m pip install --no-cache-dir --root-user-action=ignore -r /opt/build-workflow/tools/ci/requirements.txt

ENV PATH="/opt/build-workflow/tools/ci/bin:${PATH}"

ENTRYPOINT ["/opt/build-workflow/tools/ci/bin/build-workflow-ci"]
