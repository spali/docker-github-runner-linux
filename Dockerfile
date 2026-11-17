# Self-hosted GitHub Actions runner for Linux, close to ubuntu-latest for typical builds.
# Base: official runner image (Ubuntu 24.04, git, jq, curl, unzip, sudo, docker CLI).
# Self-update is disabled (entrypoint.sh): a new runner version is a new image
# (renovate bumps this tag), GitHub stops sending jobs to runners that are too old.
FROM ghcr.io/actions/actions-runner:2.338.2@sha256:6d0b2d80d80f143f77dcb676e50920100bbb547e39e883454d57f45ab8c31300

ARG TARGETARCH
# renovate: datasource=github-releases depName=mikefarah/yq
ARG YQ_VERSION=v4.54.3

USER root
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# gh from the official apt repo; build-essential for cgo (go test -race);
# zip/xz/zstd for archives and caches; shellcheck, python3 as on ubuntu-latest.
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      gh build-essential pkg-config ca-certificates gnupg file \
      zip xz-utils zstd shellcheck python3 python3-venv tzdata locales \
 && sed -i 's/^# *en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen && locale-gen \
 && curl -fsSL -o /usr/local/bin/yq \
      "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH:-amd64}" \
 && chmod +x /usr/local/bin/yq \
 && rm -rf /var/lib/apt/lists/*

ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8 \
    RUNNER_TOOL_CACHE=/opt/hostedtoolcache \
    AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache

RUN mkdir -p /opt/hostedtoolcache && chown runner:runner /opt/hostedtoolcache

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint.sh

USER runner
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
