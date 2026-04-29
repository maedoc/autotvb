# Autotvb — Container for skill-creation experiments on TVB
# Build: docker build -t autotvb .
# Run:  docker run -it --rm -v $(pwd):/app autotvb bash
# Or:   docker-compose up autotvb

FROM python:3.11-slim-bookworm

LABEL maintainer="autotvb" \
      description="Autonomous TVB skill-creation architecture"

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    nodejs \
    npm \
    build-essential \
    libgfortran5 \
    && rm -rf /var/lib/apt/lists/*

# Install pi CLI globally (Node.js tool)
RUN npm install -g @mariozechner/pi-coding-agent

# Create working directory
WORKDIR /app

# Install Python dependencies into a global venv-like location
# (we use /opt/venv instead of /tmp because /tmp is ephemeral in some container runtimes)
RUN python3 -m venv /opt/tvb_env
ENV PATH="/opt/tvb_env/bin:$PATH"
RUN pip install --no-cache-dir \
    tvb-library~=2.10 \
    tvb-data~=3.0 \
    jupyter \
    "nbconvert>=7" \
    matplotlib \
    "numpy<2" \
    scipy \
    seaborn \
    pandas \
    ipykernel

# Verify TVB import
RUN python -c "import tvb.simulator.lab; print('TVB OK')"

# Copy repo contents (Docker build context)
# In practice you mount the repo as a volume, but this layer caches deps
COPY . /app

# Make scripts executable
RUN chmod +x /app/bin/*.sh /app/init_env.sh

# Default: run init_env to ensure everything is set up, then drop to shell
ENTRYPOINT ["/app/init_env.sh"]
CMD ["bash"]
