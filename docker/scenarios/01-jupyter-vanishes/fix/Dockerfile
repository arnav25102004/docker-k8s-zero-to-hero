# D01: the AI-lab Jupyter image.
# Start from the Jupyter image we already trust, pinned to one dated tag.
FROM quay.io/jupyter/base-notebook:2026-11-02

# Lets cleanup.sh find (and remove) this image later.
LABEL z2h.scenario=d01

# Put a welcome notebook in the home folder.
COPY --chown=jovyan:users welcome.ipynb /home/jovyan/welcome.ipynb

# What the container runs when it starts.
CMD ["start-notebook.py", "--IdentityProvider.token=change-me-123"]
