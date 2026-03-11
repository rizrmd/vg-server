# Build stage
FROM ghcr.io/gleam-lang/gleam:v1.6.0-erlang-alpine AS builder

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

# Production stage
FROM erlang:27-alpine

WORKDIR /app

# Install required packages
RUN apk add --no-cache sqlite-libs

# Copy built application from builder
COPY --from=builder /app/build/ ./build/
COPY --from=builder /app/gleam.toml ./

# Create data directory for SQLite
RUN mkdir -p /data

# Set environment variables
ENV PORT=3000
ENV DB_PATH=/data/vg_server.db

# Expose the WebSocket port
EXPOSE 3000

# Run the server
CMD ["erl", "-pa", "build/erlang/ebin", "-noshell", "-eval", "application:start(compiler), application:start(vg_server)"]
