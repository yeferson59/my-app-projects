FROM python:3.13.3-alpine3.20 AS builder

RUN apk add --no-cache --virtual .build-deps \
    build-base \
    gcc \
    musl-dev \
    libffi-dev \
    && pip install --no-cache-dir uv

WORKDIR /app

COPY pyproject.toml uv.lock ./

RUN  uv sync --frozen --no-dev --no-cache --group prod \
    && find /app/.venv -name "*.pyc" -delete \
    && find /app/.venv -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

FROM python:3.13.3-alpine3.20

RUN apk add --no-cache \
    libgcc \
    libstdc++ \
    libffi \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

RUN addgroup -g 1001 -S appgroup \
    && adduser -u 1001 -S appuser -G appgroup -h /app

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv

ENV VIRTUAL_ENV=/app/.venv
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV PYTHONOPTIMIZE=2
ENV DJANGO_SETTINGS_MODULE=app.settings_prod

COPY --chown=appuser:appgroup . .

RUN python manage.py collectstatic --noinput \
    && python -m compileall -b /app \
    && find /app -name "*.py" -delete 2>/dev/null || true \
    && chown -R appuser:appgroup /app

USER appuser

HEALTHCHECK --interval=30s --timeout=3s --start-period=30s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/health/', timeout=2)" || exit 1


EXPOSE 8000

CMD ["python", "-m", "gunicorn", "app.wsgi:application", \
    "--bind", "0.0.0.0:8000", \
    "--workers", "2", \
    "--worker-class", "sync", \
    "--max-requests", "1000", \
    "--max-requests-jitter", "100", \
    "--timeout", "30", \
    "--keep-alive", "2"]
