#!/usr/bin/env bash
# Foreground access tcp for macOS LaunchAgent KeepAlive.
# Copy to e.g. ~/.local/cf-tunnel-proxy/run-access-tcp.sh and chmod +x.
# KeepAlive requires this process to stay in foreground (use exec, not nohup/background).
set -euo pipefail
HOSTNAME="${HOSTNAME_OVERRIDE:-cf-tunnel-proxy.<domain>}"
PORT="${ORIGIN_PORT:-17897}"
CFD="${CFD:-$HOME/.local/bin/cloudflared}"
exec "$CFD" access tcp --hostname "$HOSTNAME" --url "127.0.0.1:$PORT"
