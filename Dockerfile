ARG BASE_IMAGE=dhi.io/debian-base:trixie-dev
FROM ${BASE_IMAGE}

ARG DEVIN_INSTALL_URL=https://cli.devin.ai/install.sh
ARG VERSION=dev
ARG VCS_REF=unknown

LABEL org.opencontainers.image.title="Devin in a Box" \
      org.opencontainers.image.description="Run Devin CLI non-interactively in containers and CI pipelines" \
      org.opencontainers.image.url="https://github.com/junior/devin-in-a-box" \
      org.opencontainers.image.source="https://github.com/junior/devin-in-a-box" \
      org.opencontainers.image.documentation="https://github.com/junior/devin-in-a-box#readme" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="$VERSION" \
      org.opencontainers.image.revision="$VCS_REF"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN sed -i 's|http://|https://|g' \
        /etc/apt/sources.list.d/debian.sources \
        /etc/apt/sources.list.d/dhi.sources \
    && apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        ca-certificates \
        curl \
        git \
        openssh-client \
        ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 --shell /bin/bash devin

USER devin
ENV HOME=/home/devin \
    PATH=/home/devin/.local/bin:/usr/local/bin:/usr/bin:/bin \
    XDG_DATA_HOME=/home/devin/.local/share

# The official installer ends by launching the interactive setup wizard.
# Remove only that exact final command; authentication is injected at run time.
RUN curl --fail --silent --show-error --location "$DEVIN_INSTALL_URL" --output /tmp/devin-install.sh \
    && sed -i '/^"\$VERSION_DIR\/bin\/\$COMPILED_BIN_NAME" setup$/d' /tmp/devin-install.sh \
    && bash /tmp/devin-install.sh \
    && rm /tmp/devin-install.sh \
    && test -x /home/devin/.local/bin/devin

WORKDIR /workspace

RUN install -d -m 700 /home/devin/.config/devin
COPY --chown=devin:devin --chmod=600 devin-config.json /home/devin/.config/devin/config.json
COPY --chmod=755 docker-entrypoint.sh /usr/local/bin/devin-ci

ENTRYPOINT ["devin-ci"]
