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

# Collect all beam/app files into a single ebin directory
RUN mkdir -p /app/ebin && \
    for dir in build/dev/erlang/*/ebin; do \
      cp "$dir"/* /app/ebin/ 2>/dev/null || true; \
    done

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
CMD ["erl", "-pa", "ebin", "-noshell", "-eval", "'vg_server@@main':run(vg_server)"]
