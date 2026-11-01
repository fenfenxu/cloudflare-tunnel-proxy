#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
mkdir -p "$DIR/run"
PIDFILE="$DIR/run/proxy.pid"
LOG="$DIR/run/proxy.log"
AUTH_FILE="$DIR/proxy.auth"
LISTEN_HOST="${PROXY_LISTEN:-127.0.0.1}"
PORT="${PROXY_PORT:-17897}"

if [[ "$LISTEN_HOST" != "127.0.0.1" && "$LISTEN_HOST" != "::1" ]]; then
  echo "refusing non-loopback bind: $LISTEN_HOST" >&2
  exit 1
fi

if [[ -f "$PIDFILE" ]]; then
  old=$(cat "$PIDFILE" || true)
  if [[ -n "${old:-}" ]] && kill -0 "$old" 2>/dev/null; then
    echo "already running pid=$old"
    exit 0
  fi
  rm -f "$PIDFILE"
fi

if [[ ! -f "$AUTH_FILE" ]]; then
  echo "missing $AUTH_FILE (create with: printf 'user:pass\\n' > proxy.auth && chmod 600 proxy.auth)" >&2
  exit 1
fi
AUTH=$(tr -d '\n' < "$AUTH_FILE")

nohup python3 "$DIR/connect_proxy.py" --listen "$LISTEN_HOST" --port "$PORT" --auth "$AUTH" \
  >>"$LOG" 2>&1 &
echo $! >"$PIDFILE"
sleep 0.3
if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "started pid=$(cat "$PIDFILE") on ${LISTEN_HOST}:${PORT}"
else
  echo "failed to start; see $LOG" >&2
  exit 1
fi
