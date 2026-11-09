# Campus IT-Tools: the course's IT-Tools image plus a small welcome page.
FROM corentinth/it-tools:2024.10.22-7ca5393

# Who owns this image (also lets cleanup.sh find it).
LABEL z2h.scenario=d05
LABEL org.opencontainers.image.title="Campus IT-Tools"

# nginx serves everything in this folder, so hello.html appears at /hello.html
COPY hello.html /usr/share/nginx/html/hello.html
