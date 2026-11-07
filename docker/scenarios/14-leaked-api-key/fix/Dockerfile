FROM python:3.12-alpine
WORKDIR /app
COPY weather.py .
# The key is NOT an ARG and is never written to a file. A build secret is
# mounted for this one step only and leaves nothing behind in the image.
# (BuildKit, the default builder in modern Docker, understands --mount.)
RUN --mount=type=secret,id=weather_key \
    test -s /run/secrets/weather_key && echo "build check: secret was available"
# The running app gets its key from the outside: docker run -e WEATHER_API_KEY=...
CMD ["python", "weather.py"]
