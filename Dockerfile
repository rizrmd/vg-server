FROM rust:1.94-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH=/root/.local/bin:/usr/local/cargo/bin:${PATH}
ENV SPACETIME_HOST=127.0.0.1
ENV SPACETIME_PORT=3000
ENV SPACETIME_LISTEN_ADDR=0.0.0.0:3000
ENV SPACETIME_DATA_DIR=/var/lib/spacetimedb
ENV SPACETIME_DB_NAME=vg-server-20260309
ENV SPACETIME_PUBLISH_SERVER=http://127.0.0.1:3000
ENV SPACETIME_DELETE_DATA_ON_START=0

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    xz-utils \
  && rm -rf /var/lib/apt/lists/*

RUN rustup target add wasm32-unknown-unknown

RUN curl -fsSL https://install.spacetimedb.com | bash -s -- --yes

WORKDIR /app

COPY spacetimedb /app/spacetimedb
COPY docker/entrypoint.sh /app/docker/entrypoint.sh
COPY README.md /app/README.md
# Force rebuild of entrypoint
RUN touch /app/docker/entrypoint.sh && chmod +x /app/docker/entrypoint.sh

EXPOSE 3000

ENTRYPOINT ["/app/docker/entrypoint.sh"]
