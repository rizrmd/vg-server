#!/usr/bin/env bash
set -euo pipefail

SPACETIME_DATA_DIR="${SPACETIME_DATA_DIR:-/var/lib/spacetimedb}"
SPACETIME_DB_NAME="${SPACETIME_DB_NAME:-vg-server}"
SPACETIME_PUBLISH_SERVER="${SPACETIME_PUBLISH_SERVER:-http://127.0.0.1:3000}"
SPACETIME_CONFIG_DIR="${SPACETIME_DATA_DIR}/.spacetime-cli"

mkdir -p "${SPACETIME_DATA_DIR}"
mkdir -p "${SPACETIME_CONFIG_DIR}"

# Set SpacetimeDB CLI config directory to persist identity across restarts
export SPACETIME_CONFIG_DIR="${SPACETIME_CONFIG_DIR}"

# Clean up stale lock files from previous crashes/redeployments
if [ -f "${SPACETIME_DATA_DIR}/spacetime.pid" ]; then
  OLD_PID=$(cat "${SPACETIME_DATA_DIR}/spacetime.pid" 2>/dev/null || echo "")
  if [ -n "$OLD_PID" ] && ! kill -0 "$OLD_PID" 2>/dev/null; then
    echo "Removing stale PID file (process $OLD_PID no longer exists)"
    rm -f "${SPACETIME_DATA_DIR}/spacetime.pid"
  fi
fi

# Wait for control-db lock to be released (max 30 seconds)
CONTROL_DB_LOCK="${SPACETIME_DATA_DIR}/control-db/db.lock"
for i in $(seq 1 30); do
  if ! [ -f "$CONTROL_DB_LOCK" ] || flock -n "$CONTROL_DB_LOCK" -c "exit 0" 2>/dev/null; then
    break
  fi
  echo "Waiting for control-db lock... ($i/30)"
  sleep 1
done

# Start SpacetimeDB server (official image has it built-in)
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
  echo "SpacetimeDB failed to start at ${SPACETIME_PUBLISH_SERVER}" >&2
  exit 1
fi

# Publish the module (clear database to allow fresh deployments)
echo "Publishing module: ${SPACETIME_DB_NAME}..."
if ! spacetime publish "${SPACETIME_DB_NAME}" \
  --server "${SPACETIME_PUBLISH_SERVER}" \
  --module-path /app/spacetimedb \
  --anonymous \
  --clear-database \
  --yes \
  --no-config; then
  echo "Failed to publish module" >&2
  exit 1
fi

echo "SpacetimeDB ready at ${SPACETIME_PUBLISH_SERVER}"
echo "Database: ${SPACETIME_DB_NAME}"

wait "${SPACETIME_PID}"
