# Dockerfile for the Cats vs Dogs voting API (a copy of apps/api/Dockerfile).
# Every line is explained in docker/04-first-dockerfile and docker/05-production-dockerfiles.

# 1. Pin a specific, small base image (never rely on "latest").
FROM python:3.12-alpine

# 2. Metadata, visible in `docker inspect`.
LABEL org.opencontainers.image.title="z2h-showdown" \
      org.opencontainers.image.description="Cats vs Dogs live voting app for docker-k8s-zero-to-hero"

# 3. Sensible Python defaults for containers.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8080

# App settings.
ENV REDIS_HOST=localhost

# 4. Create an unprivileged user. Containers should not run as root.
RUN addgroup -S app && adduser -S -G app -u 10001 app

WORKDIR /app

# 5. Copy only what the app needs (see .dockerignore).
COPY --chown=app:app static/ static/
COPY --chown=app:app app.py .

USER 10001

# 6. Document the port (EXPOSE does not publish it; `-p` does).
EXPOSE 8080

# 7. Tell Docker how to check that the app is healthy.
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1:${PORT}/healthz || exit 1

# 8. Exec form, so the app is PID 1 and receives SIGTERM directly.
CMD ["python", "app.py"]
