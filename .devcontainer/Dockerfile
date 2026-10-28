# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/devcontainers/base:2.2.3-trixie

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
USER root

ARG DEBIAN_FRONTEND=noninteractive
ARG TARGETARCH=amd64
ARG PYTHON_VERSION=3.14
ARG NODE_VERSION=24
ARG BUN_VERSION=1.4.4
ARG OPENCODE_VERSION=2.2.0
ARG OLLAMA_VERSION=0.40.12

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_INSTALL_DIR=/usr/local/share/uv/python \
    UV_TOOL_DIR=/usr/local/share/uv/tools \
    UV_TOOL_BIN_DIR=/usr/local/bin \
    FNM_DIR=/usr/local/share/fnm \
    BUN_INSTALL=/usr/local \
    OLLAMA_MODELS=/home/vscode/.ollama/models

# Los servicios no deben arrancar durante el build (no hay systemd).
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d && chmod +x /usr/sbin/policy-rc.d

# ---------------------------------------------------------------------------
# Utilidades base del sistema
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential pkg-config make gcc g++ \
        ca-certificates gnupg \
        git curl wget \
        jq ripgrep fd-find fzf \
        tmux htop tree rsync less file vim nano \
        unzip zip zstd \
        sudo openssh-server \
        locales procps iproute2 net-tools dnsutils lsof ncdu sqlite3 \
        libssl-dev libffi-dev zlib1g-dev libbz2-dev libreadline-dev \
        libsqlite3-dev liblzma-dev libncurses-dev tk-dev uuid-dev libgdbm-dev \
        libpq-dev libgomp1 \
    && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# Apache 2.4 + PHP 8.4 + Composer
# ---------------------------------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
        apache2 libapache2-mod-php8.4 \
        php8.4-cli php8.4-common php8.4-pgsql php8.4-mbstring php8.4-xml \
        php8.4-curl php8.4-zip php8.4-gd php8.4-intl php8.4-sqlite3 \
        php8.4-opcache \
    && rm -rf /var/lib/apt/lists/*

COPY apache/000-default.conf /etc/apache2/sites-available/000-default.conf
COPY php/99-dev.ini /etc/php/8.4/apache2/conf.d/99-dev.ini
COPY php/99-dev.ini /etc/php/8.4/cli/conf.d/99-dev.ini

RUN printf 'Listen 8080\n' > /etc/apache2/ports.conf \
    && (grep -q '^ServerName' /etc/apache2/apache2.conf \
        || echo 'ServerName localhost' >> /etc/apache2/apache2.conf) \
    && a2enmod rewrite headers proxy proxy_http ssl php8.4 \
    && apache2ctl configtest

RUN curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php \
    && php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer \
    && rm -f /tmp/composer-setup.php \
    && composer --version --no-ansi

# ---------------------------------------------------------------------------
# PostgreSQL 18 (repositorio oficial PGDG)
# ---------------------------------------------------------------------------
RUN install -d -m 0755 /usr/share/postgresql-common/pgdg \
    && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
    && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends postgresql-18 postgresql-client-18 \
    && rm -rf /var/lib/apt/lists/* \
    && (test -f /var/lib/postgresql/18/main/PG_VERSION \
        || pg_createcluster 18 main --start-conf=manual) \
    && echo "listen_addresses = '*'" >> /etc/postgresql/18/main/postgresql.conf \
    && echo "host all all 0.0.0.0/0 scram-sha-256" >> /etc/postgresql/18/main/pg_hba.conf \
    && echo "host all all ::/0 scram-sha-256" >> /etc/postgresql/18/main/pg_hba.conf

# ---------------------------------------------------------------------------
# Python 3.14 gestionado por uv
# ---------------------------------------------------------------------------
RUN curl -LsSf https://astral.sh/uv/install.sh \
        | env UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh \
    && uv --version \
    && uv python install "${PYTHON_VERSION}" \
    && PYBIN="$(uv python find "${PYTHON_VERSION}")" \
    && ln -sf "${PYBIN}" "/usr/local/bin/python${PYTHON_VERSION}" \
    && ln -sf "${PYBIN}" /usr/local/bin/python3 \
    && ln -sf "${PYBIN}" /usr/local/bin/python \
    && python --version \
    && uv tool install ruff

# ---------------------------------------------------------------------------
# Node LTS con fnm
# ---------------------------------------------------------------------------
RUN curl -fsSL https://fnm.vercel.app/install \
        | bash -s -- --install-dir /usr/local/bin --skip-shell \
    && fnm --version \
    && fnm install "${NODE_VERSION}" \
    && fnm default "${NODE_VERSION}" \
    && NODE_BIN="$(ls -d "${FNM_DIR}"/node-versions/*/installation/bin | tail -n1)" \
    && for b in node npm npx corepack; do \
         [ -e "${NODE_BIN}/${b}" ] && ln -sf "${NODE_BIN}/${b}" "/usr/local/bin/${b}"; \
       done \
    && node --version && npm --version

# ---------------------------------------------------------------------------
# bun
# ---------------------------------------------------------------------------
RUN curl -fsSL https://bun.sh/install \
        | BUN_INSTALL=/usr/local BUN_VERSION="${BUN_VERSION}" bash \
    && bun --version

# ---------------------------------------------------------------------------
# OpenCode v2
# ---------------------------------------------------------------------------
RUN npm install -g --prefix /usr/local "@opencode/cli@${OPENCODE_VERSION}" \
    && opencode --version

# ---------------------------------------------------------------------------
# Ollama (CPU). Se eliminan los runners CUDA/ROCm para reducir la imagen.
# ---------------------------------------------------------------------------
RUN curl -fsSL https://ollama.com/install.sh \
        | OLLAMA_VERSION="${OLLAMA_VERSION}" sh \
    && rm -rf /usr/local/lib/ollama/cuda_v* \
              /usr/local/lib/ollama/rocm \
              /usr/local/lib/ollama/mlx* \
              /usr/local/lib/ollama/libggml-cuda.so* \
    && ollama --version \
    && du -sh /usr/local/lib/ollama

# ---------------------------------------------------------------------------
# OpenSSH server (puerto 2222, solo clave pública)
# ---------------------------------------------------------------------------
RUN mkdir -p /run/sshd \
    && ssh-keygen -A \
    && sed -i 's/^#\?Port 22$/Port 2222/' /etc/ssh/sshd_config \
    && grep -q '^Port 2222' /etc/ssh/sshd_config \
    && cat >> /etc/ssh/sshd_config <<'EOF'

# --- devcontainer ---
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
AllowUsers vscode
X11Forwarding yes
ClientAliveInterval 60
EOF
RUN sshd -t

# ---------------------------------------------------------------------------
# Integración de fnm en shells interactivos y de login
# ---------------------------------------------------------------------------
RUN cat > /etc/profile.d/20-fnm.sh <<'EOF'
export FNM_DIR=/usr/local/share/fnm
if [ -x /usr/local/bin/fnm ] && [ -z "${FNM_MULTISHELL_PATH:-}" ]; then
  eval "$(/usr/local/bin/fnm env --use-on-cd --shell bash)"
fi
EOF
RUN cat >> /etc/bash.bashrc <<'EOF'

# --- devcontainer: fnm ---
export FNM_DIR=/usr/local/share/fnm
if [ -x /usr/local/bin/fnm ] && [ -z "${FNM_MULTISHELL_PATH:-}" ]; then
  eval "$(/usr/local/bin/fnm env --use-on-cd --shell bash)"
fi
EOF

# ---------------------------------------------------------------------------
# Directorios persistidos por volúmenes (con el propietario correcto)
# ---------------------------------------------------------------------------
RUN mkdir -p /home/vscode/.ollama/models \
             /home/vscode/.cache/uv \
             /home/vscode/.cache/composer \
             /home/vscode/.config/opencode \
             /home/vscode/.local/share/opencode \
    && chown -R vscode:vscode /home/vscode/.ollama /home/vscode/.cache \
             /home/vscode/.config /home/vscode/.local

USER vscode
WORKDIR /workspaces/ioperaciones
