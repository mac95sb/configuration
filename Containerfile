FROM ghcr.io/void-linux/void-glibc:latest

ENV PIP_BREAK_SYSTEM_PACKAGES=1

RUN xbps-install -Syu && \
    xbps-install -y \
      bash \
      ca-certificates \
      curl \
      git \
      jq \
      make \
      openssh \
      pkg-config \
      python3 \
      python3-devel \
      python3-pip \
      ripgrep \
      rsync \
      sqlite \
      unzip \
      wget \
      zip \
      zsh \
      base-devel \
      nodejs && \
    update-ca-certificates && \
    xbps-remove -O

RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel && \
    python3 -m pip install --no-cache-dir \
      azure-cli \
      basedpyright \
      black \
      fastapi \
      gunicorn \
      httpx \
      mypy \
      pipx \
      pytest \
      pytest-asyncio \
      ruff \
      uv \
      "uvicorn[standard]"

RUN command -v npm >/dev/null 2>&1 && \
    npm install -g \
      @azure/static-web-apps-cli \
      @vue/language-server \
      pyright \
      typescript \
      typescript-language-server \
      vite \
      vue-tsc && \
    npm cache clean --force

RUN corepack enable 2>/dev/null || true

RUN grep -q '^staff:' /etc/group || printf '%s\n' 'staff:x:20:' >> /etc/group && \
    grep -q '^mac:' /etc/passwd || printf '%s\n' 'mac:x:501:20:mac:/Users/mac:/bin/bash' >> /etc/passwd

RUN printf '%s\n' \
      '#!/bin/sh' \
      'trap "exit 0" TERM INT' \
      'while :; do' \
      '  sleep 86400 &' \
      '  wait $!' \
      'done' \
      > /sbin/init && \
    chmod +x /sbin/init

CMD ["/bin/bash"]
