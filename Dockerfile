# Build stage
FROM ghcr.io/gleam-lang/gleam:v1.14.0-erlang-alpine AS builder

WORKDIR /app

# Copy dependency files first for better caching
COPY gleam.toml manifest.toml ./

# Download dependencies
RUN gleam deps download

# Copy source code
COPY src/ ./src/
COPY test/ ./test/

# Build the project
RUN gleam build --target erlang

# Collect all ebin directories into a flat structure for easy -pa glob
RUN mkdir -p /app/ebin && \
    find build/dev/erlang -name 'ebin' -type d -exec cp -r {}/* /app/ebin/ \;

# Production stage
FROM erlang:27-alpine

WORKDIR /app

# Copy consolidated ebin from builder
COPY --from=builder /app/ebin/ ./ebin/

# Set environment variables
ENV PORT=3000
ENV DATABASE_URL=""

# Expose the WebSocket port
EXPOSE 3000

# Run the server
CMD ["erl", "-pa", "ebin", "-noshell", "-eval", "application:start(compiler), application:start(vg_server)"]
