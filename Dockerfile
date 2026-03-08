# ======================================================================================
# DAISHODOE - HUGGING FACE SPACES DOCKERFILE 
# ======================================================================================

# Use the official Julia 1.11 image (Stable)
FROM julia:1.11-bookworm

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

# --- STABILITY & PERFORMANCE SETTINGS ---
ENV JULIA_NUM_PRECOMPILE_TASKS=1
ENV JULIA_CPU_TARGET="generic"
ENV JULIA_PKG_SERVER="https://pkg.julialang.org"
ENV JULIA_NUM_THREADS=2

# STEP 1: Download packages only (Network/IO Intensive)
RUN julia --project="." -e 'import Pkg; Pkg.instantiate()'

# STEP 2: Precompile packages (CPU Intensive - Serial mode)
RUN julia --project="." -e 'import Pkg; Pkg.precompile()'

# Expose the port Hugging Face expects
EXPOSE 7860

# Launch the Application
CMD ["julia", "--project=.", "--startup-file=no", "app.jl"]
