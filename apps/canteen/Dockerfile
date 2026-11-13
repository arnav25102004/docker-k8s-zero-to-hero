# Canteen Rush: the app behind the two course projects.
# Same production habits as the rest of the course: pinned base, non-root user, tiny image.
FROM python:3.12-alpine

# Build the same code as version 1.0 or 2.0:  docker build --build-arg VERSION=2.0.0 -t canteen:2.0.0 .
ARG VERSION=1.0.0

LABEL org.opencontainers.image.title="canteen-rush" \
      org.opencontainers.image.version="${VERSION}"

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    APP_VERSION=${VERSION}

RUN addgroup -S app && adduser -S -G app -u 10001 app
WORKDIR /app
COPY --chown=app:app static/ static/
COPY --chown=app:app app.py .
USER 10001
EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT}/healthz || exit 1

# Exec form, so the app is PID 1 and receives SIGTERM directly.
CMD ["python", "app.py"]
