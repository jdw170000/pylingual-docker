# --- Base stage with uv and pyenv setup ---
FROM ghcr.io/astral-sh/uv:python3.14-bookworm-slim AS base

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy
ENV UV_NO_DEV=1
ENV UV_PYTHON_INSTALL_DIR=/usr/local/python
ENV UV_TOOL_DIR=/usr/local/share/uv/tools
ENV UV_TOOL_BIN_DIR=/usr/local/bin
ENV PYENV_ROOT="/usr/share/.pyenv"
ENV PATH="$PYENV_ROOT/bin:$PYENV_ROOT/shims:$PATH"

# Install pyenv
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates git build-essential libssl-dev zlib1g-dev \
    libbz2-dev libreadline-dev libsqlite3-dev wget llvm libncurses5-dev \
    libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev && \
    curl -fsSL https://pyenv.run | bash && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Stage for pre-installing all Python versions (Full) ---
FROM base AS full-pythons
RUN uv python install 3.8 3.9 3.10 3.11 3.12 3.13 3.14
RUN pyenv install 3.6 3.7

# --- Full CLI ---
FROM full-pythons AS full-cli
WORKDIR /app
COPY pylingual /app/pylingual
RUN uv tool install /app/pylingual
ENTRYPOINT ["pylingual"]

# --- Lite CLI ---
FROM base AS lite-cli
WORKDIR /app
COPY pylingual /app/pylingual
RUN uv tool install /app/pylingual
ENTRYPOINT ["pylingual"]

# --- Full Server ---
FROM full-pythons AS full-server
WORKDIR /app/pylingual-server
COPY pylingual /app/pylingual
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pylingual-server/uv.lock,target=uv.lock \
    --mount=type=bind,source=pylingual-server/pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project
COPY pylingual-server /app/pylingual-server
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked
ENV PATH="/app/pylingual-server/.venv/bin:$PATH"
ENTRYPOINT []
EXPOSE 8000
CMD ["fastapi", "run", "main:app", "--port", "8000", "--host", "0.0.0.0"]

# --- Lite Server ---
FROM base AS lite-server
WORKDIR /app/pylingual-server
COPY pylingual /app/pylingual
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=pylingual-server/uv.lock,target=uv.lock \
    --mount=type=bind,source=pylingual-server/pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project
COPY pylingual-server /app/pylingual-server
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked
ENV PATH="/app/pylingual-server/.venv/bin:$PATH"
ENTRYPOINT []
EXPOSE 8000
CMD ["fastapi", "run", "main.py", "--port", "8000", "--host", "0.0.0.0"]