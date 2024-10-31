FROM ubuntu:22.04 AS docker-compose-downloader
ARG TARGETARCH
RUN apt-get update && apt-get install curl -y
COPY ./install-docker-compose.sh /install-docker-compose.sh
RUN ./install-docker-compose.sh

FROM ubuntu:22.04
LABEL maintainer="Guilherme Oliveira"

# Args
ARG BUILD_DATE
ARG REVISION
ARG BUILD_VERSION
ARG DEBIAN_FRONTEND=noninteractive

# Labels
LABEL \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.description="Default image for Bitbucket Pipelines" \
    org.opencontainers.image.revision=$REVISION \
    org.opencontainers.image.version=$BUILD_VERSION

# Install base dependencies
RUN apt-get update \
    && apt-get install -y \
        software-properties-common \
    && add-apt-repository ppa:git-core/ppa -y \
    && apt-get install -y \
        autoconf \
        build-essential \
        ca-certificates \
        pkg-config \
        wget \
        xvfb \
        curl \
        git \
        ant \
        ssh-client \
        unzip \
        iputils-ping \
        zip \
        jq \
        gettext-base \
        tar \
        parallel \
    && rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# install docker-compose
COPY --from=docker-compose-downloader /usr/local/bin/docker-compose /usr/local/bin/docker-compose
# Test Docker Compose install
RUN docker-compose version

# Install nvm with node and npm
ENV NODE_VERSION=18.20.4 \
    NVM_DIR=/root/.nvm \
    NVM_VERSION=0.40.1 \
    NVM_SHA256=abdb525ee9f5b48b34d8ed9fc67c6013fb0f659712e401ecd88ab989b3af8f53

RUN curl https://raw.githubusercontent.com/nvm-sh/nvm/v$NVM_VERSION/install.sh -o install_nvm.sh \
    && echo "${NVM_SHA256} install_nvm.sh" | sha256sum -c - \
    && bash install_nvm.sh \
    && rm -rf install_nvm.sh \
    && . $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

# Set node path
ENV NODE_PATH=$NVM_DIR/v$NODE_VERSION/lib/node_modules

# Default to UTF-8 file.encoding
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    LANGUAGE=C.UTF-8

# Xvfb provide an in-memory X-session for tests that require a GUI
ENV DISPLAY=:99

# Set the path.
ENV PATH=$NVM_DIR:$NVM_DIR/versions/node/v$NODE_VERSION/bin:$PATH

# Create dirs and users
RUN mkdir -p /opt/atlassian/bitbucketci/agent/build \
    && sed -i '/[ -z \"PS1\" ] && return/a\\ncase $- in\n*i*) ;;\n*) return;;\nesac' /root/.bashrc \
    && useradd --create-home --shell /bin/bash --uid 1000 pipelines

WORKDIR /opt/atlassian/bitbucketci/agent/build
ENTRYPOINT ["/bin/bash"]

