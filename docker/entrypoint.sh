#!/usr/bin/env bash
set -euo pipefail

SPACETIME_DB_NAME="vg-server"
SPACETIME_DATA_DIR="${SPACETIME_DATA_DIR:-/var/lib/spacetimedb}"
SPACETIME_PUBLISH_SERVER="${SPACETIME_PUBLISH_SERVER:-http://127.0.0.1:3000}"
SPACETIME_CONFIG_DIR="${SPACETIME_DATA_DIR}/.spacetime-cli"

# Always start fresh - wipe all data
if [ -d "${SPACETIME_DATA_DIR}" ]; then
  echo "Wiping existing data..."
  rm -rf "${SPACETIME_DATA_DIR:?}"/*
fi

mkdir -p "${SPACETIME_DATA_DIR}"
mkdir -p "${SPACETIME_CONFIG_DIR}"

export SPACETIME_CONFIG_DIR="${SPACETIME_CONFIG_DIR}"

# Start SpacetimeDB server
spacetime start \
  --listen-addr '0.0.0.0:3000' \
  --data-dir "${SPACETIME_DATA_DIR}" \
  --non-interactive &

SPACETIME_PID=$!

cleanup() {
  if kill -0 "${SPACETIME_PID}" >/dev/null 2>&1; then
    kill "${SPACETIME_PID}" >/dev/null 2>&1 || true
    wait "${SPACETIME_PID}" || true
  fi
}

trap cleanup EXIT INT TERM

# Wait for server to be healthy
for _ in $(seq 1 60); do
  if curl -fsS "${SPACETIME_PUBLISH_SERVER}/v1/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! curl -fsS "${SPACETIME_PUBLISH_SERVER}/v1/health" >/dev/null 2>&1; then
  echo "SpacetimeDB failed to start" >&2
  exit 1
fi

# Publish the module
echo "Publishing database: ${SPACETIME_DB_NAME}..."
if ! spacetime publish "${SPACETIME_DB_NAME}" \
  --server "${SPACETIME_PUBLISH_SERVER}" \
  --module-path /app/spacetimedb \
  --anonymous \
  --yes \
  --no-config; then
  echo "Failed to publish module" >&2
  exit 1
fi

echo "SpacetimeDB ready: ${SPACETIME_PUBLISH_SERVER}/${SPACETIME_DB_NAME}"

wait "${SPACETIME_PID}"
