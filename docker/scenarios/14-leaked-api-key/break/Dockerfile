FROM python:3.12-alpine
WORKDIR /app
COPY weather.py .
# Quick hack before the demo: the build gets the key as an argument...
ARG WEATHER_API_KEY
# ...and writes it into a config file. Every RUN step is saved in the image.
RUN echo "key=$WEATHER_API_KEY" > /app/config
CMD ["python", "weather.py"]
