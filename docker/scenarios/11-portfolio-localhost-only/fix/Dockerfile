FROM python:3.12-alpine
WORKDIR /site
COPY site/ /site/
ENV PYTHONUNBUFFERED=1
EXPOSE 8000
# FIX: --bind 0.0.0.0 means "accept visitors on every network interface", so the published port works.
CMD ["python", "-m", "http.server", "8000", "--bind", "0.0.0.0"]
