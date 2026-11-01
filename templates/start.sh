#!/usr/bin/env bash
# Start local HTTP CONNECT proxy on loopback only.
# Default: gost (PROXY_BACKEND=auto|gost|python). Python connect_proxy.py is fallback.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
mkdir -p "$DIR/run"
PIDFILE="$DIR/run/proxy.pid"
LOG="$DIR/run/proxy.log"
AUTH_FILE="$DIR/proxy.auth"
LISTEN_HOST="${PROXY_LISTEN:-127.0.0.1}"
PORT="${PROXY_PORT:-17897}"
BACKEND="${PROXY_BACKEND:-auto}"

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
  echo "missing $AUTH_FILE (create with: printf 'user:pass\n' > proxy.auth && chmod 600 proxy.auth)" >&2
  exit 1
fi
AUTH=$(tr -d '\n\r' < "$AUTH_FILE")
if [[ "$AUTH" != *:* ]]; then
  echo "proxy.auth must be user:pass (one line)" >&2
  exit 1
fi

# install-gost.sh puts the binary in ~/.local/bin. ensure/cron often skip shell rc,
# so search that directory before auto falls back to Python.
if ! command -v gost >/dev/null 2>&1; then
  export PATH="${GOST_BIN_DIR:-$HOME/.local/bin}:$PATH"
fi

pick_backend() {
  case "$BACKEND" in
    gost) echo gost ;;
    python|py) echo python ;;
    auto|"")
      if command -v gost >/dev/null 2>&1; then
        echo gost
      else
        echo python
      fi
      ;;
    *)
      echo "unknown PROXY_BACKEND=$BACKEND (use auto|gost|python)" >&2
      exit 1
      ;;
  esac
}

BACKEND_RESOLVED="$(pick_backend)"
echo "proxy backend=$BACKEND_RESOLVED" >>"$LOG"

if [[ "$BACKEND_RESOLVED" == gost ]]; then
  if ! command -v gost >/dev/null 2>&1; then
    echo "gost not in PATH; install gost or set PROXY_BACKEND=python" >&2
    exit 1
  fi
  # -L=http://USER:PASS@127.0.0.1:PORT — HTTP proxy with Basic; CONNECT for HTTPS
  nohup gost "-L=http://${AUTH}@${LISTEN_HOST}:${PORT}" >>"$LOG" 2>&1 &
else
  if [[ ! -f "$DIR/connect_proxy.py" ]]; then
    echo "missing connect_proxy.py for python fallback" >&2
    exit 1
  fi
  nohup python3 "$DIR/connect_proxy.py" --listen "$LISTEN_HOST" --port "$PORT" --auth "$AUTH"     >>"$LOG" 2>&1 &
fi
echo $! >"$PIDFILE"
sleep 0.4
if kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "started backend=$BACKEND_RESOLVED pid=$(cat "$PIDFILE") on ${LISTEN_HOST}:${PORT}"
else
  echo "failed to start; see $LOG" >&2
  exit 1
fi
