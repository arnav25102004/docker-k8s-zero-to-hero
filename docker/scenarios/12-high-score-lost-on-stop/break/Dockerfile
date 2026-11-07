FROM python:3.12-alpine
WORKDIR /app
COPY server.py index.html ./
ENV PYTHONUNBUFFERED=1
RUN mkdir -p /data
EXPOSE 8000
# BUG: shell form. Docker runs this as: /bin/sh -c "python server.py | tee ...",
# so the shell (not Python) is PID 1, and it never passes SIGTERM on.
CMD python server.py | tee /data/server.log
