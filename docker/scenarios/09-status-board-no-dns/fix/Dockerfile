# D09: the campus status board, a tiny Python script that checks two apps by name.
FROM python:3.12-alpine

# Lets you see which scenario built this image (docker image inspect).
LABEL z2h.scenario=d09

COPY board.py /board.py
EXPOSE 8000
CMD ["python", "-u", "/board.py"]
