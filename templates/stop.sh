#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PIDFILE="$DIR/run/proxy.pid"
if [[ -f "$PIDFILE" ]]; then
  pid=$(cat "$PIDFILE")
  kill "$pid" 2>/dev/null || true
  rm -f "$PIDFILE"
  echo "stopped $pid"
else
  echo "not running"
fi
