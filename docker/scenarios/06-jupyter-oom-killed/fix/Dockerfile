# The trainer: a small Python script on a small Python image.
FROM python:3.12-alpine

# Lets cleanup.sh find (and remove) this image later.
LABEL z2h.scenario=d06

WORKDIR /app
COPY trainer.py .
CMD ["python", "trainer.py"]
