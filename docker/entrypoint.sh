#!/usr/bin/env bash
set -euo pipefail

SPACETIME_HOST="${SPACETIME_HOST:-127.0.0.1}"
SPACETIME_PORT="${SPACETIME_PORT:-3000}"
SPACETIME_LISTEN_ADDR="${SPACETIME_LISTEN_ADDR:-0.0.0.0:${SPACETIME_PORT}}"
SPACETIME_DATA_DIR="${SPACETIME_DATA_DIR:-/var/lib/spacetimedb}"
SPACETIME_DB_NAME="vg-server-final"
SPACETIME_PUBLISH_SERVER="${SPACETIME_PUBLISH_SERVER:-http://${SPACETIME_HOST}:${SPACETIME_PORT}}"

mkdir -p "${SPACETIME_DATA_DIR}"

# Clean up stale lock files from previous crashes/redeployments
# This handles the case where Coolify starts new container before stopping old one
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

spacetime start \
  --listen-addr "${SPACETIME_LISTEN_ADDR}" \
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

if [[ "${SPACETIME_DELETE_DATA_ON_START:-0}" == "1" ]]; then
  DELETE_FLAG="--delete-data=always"
else
  DELETE_FLAG=""
fi

if [[ -n "${DELETE_FLAG}" ]]; then
  spacetime publish "${SPACETIME_DB_NAME}" \
    --server "${SPACETIME_PUBLISH_SERVER}" \
    --module-path /app/spacetimedb \
    --anonymous \
    --yes \
    --no-config \
    ${DELETE_FLAG}
else
  spacetime publish "${SPACETIME_DB_NAME}" \
    --server "${SPACETIME_PUBLISH_SERVER}" \
    --module-path /app/spacetimedb \
    --anonymous \
    --yes \
    --no-config
fi

echo "SpacetimeDB server ready at ${SPACETIME_PUBLISH_SERVER}"
echo "Published database: ${SPACETIME_DB_NAME}"

wait "${SPACETIME_PID}"
