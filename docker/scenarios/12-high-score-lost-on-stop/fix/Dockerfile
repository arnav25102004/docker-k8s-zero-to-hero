FROM python:3.12-alpine
WORKDIR /app
COPY server.py index.html ./
ENV PYTHONUNBUFFERED=1
RUN mkdir -p /data
EXPOSE 8000
# FIX: exec form. Python is PID 1, so it receives SIGTERM and saves the scores.
CMD ["python", "server.py"]
