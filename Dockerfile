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

# Build the project and create an erlang shipment
RUN gleam export erlang-shipment

# Production stage
FROM erlang:28-alpine

WORKDIR /app

# Copy the erlang shipment
COPY --from=builder /app/build/erlang-shipment/ ./

# Set environment variables
ENV PORT=3000
ENV DATABASE_URL=""

# Expose the WebSocket port
EXPOSE 3000

# Run the server using the shipment entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["run"]
