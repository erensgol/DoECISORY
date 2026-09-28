# ======================================================================================
# DOECISORY - HUGGING FACE SPACES DOCKERFILE 
# ======================================================================================

FROM julia:1.12-bookworm

USER root
RUN apt-get update && apt-get install -y \
    libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxfixes3 libxrandr2 libgbm1 libasound2 libpango-1.0-0 \
    libcairo2 unzip xvfb libgtk-3-0 libsoup2.4-1 libarchive13 \
    libx11-6 libx11-xcb1 libxcb1 libxcursor1 libxi6 libxtst6 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    JULIA_DEPOT_PATH=/home/user/.julia \
    JULIA_WEBIO_BASEURL=http://0.0.0.0:7860/ \
    GKSwstype=100

WORKDIR $HOME/app
COPY --chown=user:user . .

ENV JULIA_NUM_PRECOMPILE_TASKS=1
ENV JULIA_CPU_TARGET="generic"
ENV JULIA_PKG_SERVER="https://pkg.julialang.org"
ENV JULIA_NUM_THREADS=2
ENV PORT=7860

RUN julia --project="." -e 'import Pkg; Pkg.instantiate(); Pkg.precompile()'

EXPOSE 7860
ENV JULIA_PKG_OFFLINE=true

CMD ["julia", "--project=.", "--startup-file=no", "--banner=no", "app.jl"]
