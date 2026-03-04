# ======================================================================================
# DAISHODOE - HUGGING FACE SPACES DOCKERFILE
# ======================================================================================

# Use the official Julia 1.12 image as a parent image
FROM julia:1.12

# Temporarily switch to root to install missing system dependencies for Plotly Kaleido
USER root
RUN apt-get update && apt-get install -y \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxfixes3 libxrandr2 libgbm1 libasound2 libpango-1.0-0 \
    libcairo2 unzip xvfb \
    && rm -rf /var/lib/apt/lists/*

# Security and permissions required by Hugging Face Spaces
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    JULIA_DEPOT_PATH=/home/user/.julia

# Set the working directory
WORKDIR $HOME/app

# Copy application files
COPY --chown=user:user . .

# Switch back to user
USER user

# Instantiate the Julia environment and Precompile
RUN julia --project="." -e 'import Pkg; Pkg.instantiate(); Pkg.precompile()'

# Expose the port Hugging Face expects
EXPOSE 7860

# Launch the Application. 
# Explicitly injecting -t auto to ensure multi-threaded execution dynamically checks CPU Cores.
CMD ["julia", "-t", "auto", "--project=.", "app.jl"]
