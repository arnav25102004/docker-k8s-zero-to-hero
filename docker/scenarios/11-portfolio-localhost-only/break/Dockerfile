FROM python:3.12-alpine
WORKDIR /site
COPY site/ /site/
ENV PYTHONUNBUFFERED=1
EXPOSE 8000
# BUG: --bind 127.0.0.1 means "only accept visitors from inside this container".
CMD ["python", "-m", "http.server", "8000", "--bind", "127.0.0.1"]
