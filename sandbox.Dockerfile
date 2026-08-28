ARG BASE_IMAGE=docker.io/docker/sandbox-templates:shell
FROM ${BASE_IMAGE}

ARG DEVIN_INSTALL_URL=https://cli.devin.ai/install.sh
ARG VERSION=dev
ARG VCS_REF=unknown

LABEL org.opencontainers.image.title="Devin in a Box — Docker Sandbox" \
      org.opencontainers.image.description="Run Devin CLI as a custom Docker Sandboxes agent" \
      org.opencontainers.image.url="https://github.com/junior/devin-in-a-box" \
      org.opencontainers.image.source="https://github.com/junior/devin-in-a-box" \
      org.opencontainers.image.documentation="https://github.com/junior/devin-in-a-box#docker-sandboxes" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$VCS_REF"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

USER root
RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        ca-certificates \
        curl \
        git \
        openssh-client \
        ripgrep \
    && rm -rf /var/lib/apt/lists/*

USER agent
ENV PATH=/home/agent/.local/bin:/usr/local/bin:/usr/bin:/bin \
    XDG_DATA_HOME=/home/agent/.local/share

# The official installer ends by launching its interactive setup wizard.
# Authentication is supplied later by the Docker Sandboxes host proxy.
RUN curl --fail --silent --show-error --location "$DEVIN_INSTALL_URL" --output /tmp/devin-install.sh \
    && sed -i '/^"\$VERSION_DIR\/bin\/\$COMPILED_BIN_NAME" setup$/d' /tmp/devin-install.sh \
    && bash /tmp/devin-install.sh \
    && rm /tmp/devin-install.sh \
    && test -x /home/agent/.local/bin/devin

WORKDIR /workspace
