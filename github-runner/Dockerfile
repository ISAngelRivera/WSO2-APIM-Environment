# GitHub Actions Self-Hosted Runner
# Base: Ubuntu 22.04 (compatible con RedHat en producción)
#
# Dependencias incluidas para APIOps:
# - curl, jq: Para llamadas API REST
# - git: Para operaciones Git
# - zip/unzip: Para exportar APIs
# - apictl: WSO2 API Controller
# - python3: Para parsear YAML

FROM ubuntu:22.04

# Evitar prompts interactivos
ENV DEBIAN_FRONTEND=noninteractive

# Metadata
LABEL maintainer="APIOps Team"
LABEL description="GitHub Actions Runner for WSO2 APIOps"
LABEL version="1.1"

# Instalar dependencias base incluyendo OpenSSL actualizado
RUN apt-get update && apt-get install -y \
    curl \
    jq \
    git \
    zip \
    unzip \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    python3 \
    python3-pip \
    openssl \
    libssl3 \
    libicu70 \
    && update-ca-certificates \
    && pip3 install pyyaml \
    && rm -rf /var/lib/apt/lists/*

# Configurar OpenSSL para permitir algoritmos legacy (fix ARM64 SSL issues)
RUN sed -i 's/openssl_conf = openssl_init/openssl_conf = openssl_init\n\n[openssl_init]\nssl_conf = ssl_sect\n\n[ssl_sect]\nsystem_default = system_default_sect\n\n[system_default_sect]\nMinProtocol = TLSv1.2\nCipherString = DEFAULT@SECLEVEL=1/' /etc/ssl/openssl.cnf || true

# Instalar GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario para el runner (no root por seguridad)
RUN useradd -m -s /bin/bash runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Instalar WSO2 API Controller (apictl) - versión 4.3.0
ARG APICTL_VERSION=4.3.0
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then \
      APICTL_ARCH="linux-arm64"; \
    else \
      APICTL_ARCH="linux-amd64"; \
    fi && \
    echo "Downloading apictl $APICTL_VERSION for $APICTL_ARCH..." && \
    mkdir -p /home/runner/.local/bin/apictl && \
    curl -L "https://github.com/wso2/product-apim-tooling/releases/download/v${APICTL_VERSION}/apictl-${APICTL_VERSION}-${APICTL_ARCH}.tar.gz" \
    -o /tmp/apictl.tar.gz && \
    tar -xzf /tmp/apictl.tar.gz -C /home/runner/.local/bin/apictl && \
    rm /tmp/apictl.tar.gz && \
    chmod +x /home/runner/.local/bin/apictl/apictl && \
    chown -R runner:runner /home/runner/.local

# Versión del runner de GitHub Actions (2.321.0 tiene mejor soporte SSL para ARM64)
ARG RUNNER_VERSION=2.321.0

# Descargar e instalar el runner (detecta arquitectura automáticamente)
WORKDIR /home/runner
RUN ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then \
      RUNNER_ARCH="linux-arm64"; \
    else \
      RUNNER_ARCH="linux-x64"; \
    fi && \
    echo "Downloading runner for $RUNNER_ARCH..." && \
    curl -o actions-runner.tar.gz -L \
    https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz \
    && tar xzf actions-runner.tar.gz \
    && rm actions-runner.tar.gz \
    && chown -R runner:runner /home/runner

# Instalar dependencias del runner
RUN ./bin/installdependencies.sh

# Copiar script de entrada (con permisos para todos)
COPY entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

# Cambiar al usuario runner
USER runner

# Variables de entorno requeridas (se pasan en docker-compose)
ENV RUNNER_NAME=""
ENV GITHUB_TOKEN=""
ENV GITHUB_OWNER=""
ENV GITHUB_REPO=""
ENV RUNNER_LABELS="self-hosted,linux,apiops"
ENV RUNNER_WORKDIR="/home/runner/_work"

# Fix SSL issues con .NET en ARM64/OpenSSL 3.x
# El runner de GitHub usa .NET que tiene problemas con OpenSSL 3.x en ARM64
ENV DOTNET_SYSTEM_NET_HTTP_USESOCKETSHTTPHANDLER=0
ENV SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
# Forzar uso de HttpClientHandler nativo
ENV DOTNET_SYSTEM_NET_HTTP_SOCKETSHTTPHANDLER_HTTP3SUPPORT=0
# Usar configuración OpenSSL legacy
ENV OPENSSL_CONF=/etc/ssl/openssl_legacy.cnf

ENTRYPOINT ["/entrypoint.sh"]
