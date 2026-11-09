# Campus tools page: the course's IT-Tools image plus a health check of our own.
FROM corentinth/it-tools:2024.10.22-7ca5933

# Who owns this image (also lets cleanup.sh find it).
LABEL z2h.scenario=d08

# Every 3 seconds Docker runs this command INSIDE the container.
# Exit code 0 = healthy. Two failures in a row = the container is marked unhealthy.
HEALTHCHECK --interval=3s --timeout=2s --retries=2 \
  CMD wget -qO- http://127.0.0.1:80/ || exit 1
