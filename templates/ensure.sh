#!/usr/bin/env bash
# Ensure local CONNECT proxy is up (gost preferred via start.sh; python fallback).
# Safe to cron / call from shell rc. PROXY_BACKEND=auto|gost|python
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PIDFILE="$DIR/run/proxy.pid"
PORT="${PROXY_PORT:-17897}"
if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  if ss -ltn 2>/dev/null | grep -q "127.0.0.1:${PORT}"; then
    exit 0
  fi
fi
exec "$DIR/start.sh"
