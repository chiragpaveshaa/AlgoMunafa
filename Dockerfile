FROM python:3.11-slim AS runtime-base

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    ca-certificates \
    && curl -L https://sourceforge.net/projects/ta-lib/files/ta-lib/0.4.0/ta-lib-0.4.0-src.tar.gz/download \
       -o /tmp/ta-lib.tar.gz \
    && tar -xzf /tmp/ta-lib.tar.gz -C /tmp \
    && cd /tmp/ta-lib \
	&& ./configure --prefix=/usr/local \
	&& make \
	&& make install \
	&& ldconfig \
    && rm -rf /tmp/ta-lib /tmp/ta-lib.tar.gz \
    && rm -rf /var/lib/apt/lists/*

# Local docker-compose.yml (dev dependencies, hot-path parity)
FROM runtime-base AS development

COPY pyproject.toml .
RUN pip install -e ".[dev]"

COPY . .

RUN mkdir -p keys && \
    if [ ! -f keys/private.pem ]; then \
        openssl genrsa -out keys/private.pem 2048 && \
        openssl rsa -in keys/private.pem -pubout -out keys/public.pem; \
    fi

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]

# Production image (no dev deps; non-root; PORT from platform)
FROM runtime-base AS production

ARG INSTALL_BACKTEST=false

COPY pyproject.toml .
RUN pip install . \
    && if [ "$INSTALL_BACKTEST" = "true" ]; then pip install ".[backtest]"; fi

COPY . .

RUN chmod +x deploy/docker-entrypoint.sh \
    && useradd --create-home --uid 10001 appuser \
    && mkdir -p keys \
    && chown -R appuser:appuser /app

USER appuser

ENV PORT=8000
EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT}/health" || exit 1

ENTRYPOINT ["/app/deploy/docker-entrypoint.sh"]

# Default target matches existing local Docker Compose behavior.
FROM development
