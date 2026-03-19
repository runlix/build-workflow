FROM debian:bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates git jq \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY tools/ci/bin/build-workflow-ci /usr/local/bin/build-workflow-ci

ENTRYPOINT ["build-workflow-ci"]
