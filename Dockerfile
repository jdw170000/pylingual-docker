# syntax=docker/dockerfile:1

# ==========================================
# 1. Pyenv Builder: Build EOL Pythons (3.6, 3.7)
# ==========================================
FROM debian:bookworm-slim AS pyenv-builder

ENV PYENV_ROOT="/usr/share/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# Install build dependencies for pyenv
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncurses5-dev \
    libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev \
    && rm -rf /var/lib/apt/lists/*

# Install pyenv
RUN curl -fsSL https://pyenv.run | bash

# Install EOL Python versions
RUN pyenv install 3.6 3.7

# ==========================================
# 2. Runtime Base (UV based)
# ==========================================
FROM ghcr.io/astral-sh/uv:python3.14-bookworm-slim AS runtime-base

ENV UV_COMPILE_BYTECODE=1 UV_LINK_MODE=copy
ENV PYENV_ROOT="/usr/share/.pyenv"
ENV PATH="/home/pylingual/.local/bin:$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"
ENV HF_HOME="/home/pylingual/.cache/huggingface"

# Configure UV for non-root user
ENV UV_TOOL_BIN_DIR="/home/pylingual/.local/bin"
ENV UV_TOOL_DIR="/home/pylingual/.local/share/uv/tools"
ENV UV_PYTHON_INSTALL_DIR="/home/pylingual/.local/share/uv/python"

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 libsqlite3-0 libbz2-1.0 libreadline8 libncursesw6 liblzma5 libxml2 libxmlsec1-openssl \
    ca-certificates git \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -u 1000 pylingual
WORKDIR /app
RUN chown pylingual:pylingual /app
RUN mkdir -p /home/pylingual/.cache/huggingface /home/pylingual/.local/share/uv/python \
    && chown -R pylingual:pylingual /home/pylingual/.cache /home/pylingual/.local

# ==========================================
# 3. Model Downloader (for Full images)
# ==========================================
FROM runtime-base AS model-builder

USER pylingual
COPY --chown=pylingual:pylingual pylingual /app/pylingual
COPY --chown=pylingual:pylingual scripts /app/scripts

# Run download script
RUN --mount=type=cache,target=/home/pylingual/.cache/uv,uid=1000 \
    uv run --directory /app/pylingual --script /app/scripts/download_models.py

# ==========================================
# 4. Target: Lite CLI
# ==========================================
FROM runtime-base AS lite-cli
USER pylingual
COPY --chown=pylingual:pylingual pylingual /app/pylingual
RUN --mount=type=cache,target=/home/pylingual/.cache/uv,uid=1000 \
    uv tool install /app/pylingual
ENTRYPOINT ["pylingual"]

# ==========================================
# 5. Target: Full CLI
# ==========================================
FROM runtime-base AS full-cli

# Copy pyenv versions
COPY --from=pyenv-builder /usr/share/.pyenv /usr/share/.pyenv
RUN chmod -R a+rX /usr/share/.pyenv

USER pylingual

# Install UV managed versions (3.8 - 3.13)
# 3.14 is already in the base image
RUN uv python install 3.8 3.9 3.10 3.11 3.12 3.13

# Copy pre-downloaded models
COPY --from=model-builder --chown=pylingual:pylingual /home/pylingual/.cache/huggingface /home/pylingual/.cache/huggingface

COPY --chown=pylingual:pylingual pylingual /app/pylingual
RUN --mount=type=cache,target=/home/pylingual/.cache/uv,uid=1000 \
    uv tool install /app/pylingual
ENTRYPOINT ["pylingual"]

# ==========================================
# 6. Target: Lite Server
# ==========================================
FROM runtime-base AS lite-server
USER pylingual
WORKDIR /app/pylingual-server
COPY --chown=pylingual:pylingual pylingual /app/pylingual
COPY --chown=pylingual:pylingual pylingual-server /app/pylingual-server

RUN --mount=type=cache,target=/home/pylingual/.cache/uv,uid=1000 \
    uv sync --locked --no-install-project --project /app/pylingual-server

RUN --mount=type=cache,target=/home/pylingual/.cache/uv,uid=1000 \
    uv sync --locked --project /app/pylingual-server

ENV PATH="/app/pylingual-server/.venv/bin:$PATH"
EXPOSE 8000
CMD ["fastapi", "run", "main.py", "--port", "8000", "--host", "0.0.0.0"]

# ==========================================
# 7. Target: Full Server
# ==========================================
FROM runtime-base AS full-server
USER pylingual
WORKDIR /app/pylingual-server

# Copy pyenv versions
COPY --from=pyenv-builder /usr/share/.pyenv /usr/share/.pyenv
RUN chmod -R a+rX /usr/share/.pyenv

USER pylingual

# Install UV managed versions (3.8 - 3.13)
RUN uv python install 3.8 3.9 3.10 3.11 3.12 3.13

# Copy pre-downloaded models
COPY --from=model-builder --chown=pylingual:pylingual /home/pylingual/.cache/huggingface /home/pylingual/.cache/huggingface

COPY --chown=pylingual:pylingual pylingual /app/pylingual
COPY --chown=pylingual:pylingual pylingual-server /app/pylingual-server

RUN --mount=type=cache,target=/home/pylingual/.cache/uv,uid=1000 \
    uv sync --locked --no-install-project --project /app/pylingual-server

RUN --mount=type=cache,target=/home/pylingual/.cache/uv,uid=1000 \
    uv sync --locked --project /app/pylingual-server

ENV PATH="/app/pylingual-server/.venv/bin:$PATH"
EXPOSE 8000
CMD ["fastapi", "run", "main.py", "--port", "8000", "--host", "0.0.0.0"]