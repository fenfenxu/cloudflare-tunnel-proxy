#!/usr/bin/env bash
# Ensure one named tunnel is up. Customize CFG / TUNNEL_ID / start command.
# Local ha_connections can lie (zombie): also require `cloudflared tunnel info`
# to list ≥1 connector; otherwise force-kill and let the wrapper respawn.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
CFG="${CFG:-$HOME/.cloudflared/tunnel.yml}"
TUNNEL_ID="${TUNNEL_ID:?set TUNNEL_ID to the named tunnel UUID}"
CFD="${CFD:-$HOME/.local/bin/cloudflared}"
LOG="${LOG:-$DIR/run/tunnel-ensure.log}"
mkdir -p "$(dirname "$LOG")"

pid=""
while read -r p; do
  comm=$(ps -p "$p" -o comm= 2>/dev/null | tr -d ' ')
  if [[ "$comm" == *cloudflared* ]]; then pid=$p; break; fi
done < <(pgrep -f "cloudflared tunnel .*--config ${CFG}" || true)

if [[ -z "${pid}" ]]; then
  echo "$(date -Is) cloudflared down -> start your tunnel run wrapper here" >>"$LOG"
  exit 0
fi

metrics_port=$(ss -ltnp 2>/dev/null | grep "pid=${pid}," | grep -oE '127\.0\.0\.1:202[0-9]+' | head -1 | cut -d: -f2 || true)
ha=""
if [[ -n "${metrics_port}" ]]; then
  ha=$(curl -fsS --max-time 2 "http://127.0.0.1:${metrics_port}/metrics" 2>/dev/null \
    | awk '/^cloudflared_tunnel_ha_connections /{print int($2)}' || true)
fi

cf_connectors=0
if [[ -x "$CFD" ]]; then
  info_out=$("$CFD" tunnel info "$TUNNEL_ID" 2>/dev/null || true)
  cf_connectors=$(printf '%s\n' "$info_out" | awk 'BEGIN{c=0} /^[0-9a-f]{8}-[0-9a-f]{4}-/{c++} END{print c}')
fi

zombie=0
if [[ -n "${ha}" && "${ha}" -ge 1 && "${cf_connectors}" -lt 1 ]]; then
  zombie=1
fi

if [[ (-n "${ha}" && "${ha}" -lt 1) || "${zombie}" -eq 1 ]]; then
  echo "$(date -Is) pid=${pid} ha=${ha:-na} cf_connectors=${cf_connectors} zombie=${zombie} -> kill" >>"$LOG"
  kill "$pid" 2>/dev/null || true
else
  echo "$(date -Is) ok pid=${pid} ha=${ha:-na} cf_connectors=${cf_connectors}" >>"$LOG"
fi
