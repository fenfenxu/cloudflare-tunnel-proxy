#!/usr/bin/env bash
# Ensure one named tunnel is up. Customize via env — do not hardcode a production name.
#
# Required: TUNNEL_ID (named tunnel UUID)
# Optional:
#   CFG     cloudflared config path (default: $HOME/.cloudflared/tunnel.yml)
#   CFD     cloudflared binary (default: $HOME/.local/bin/cloudflared)
#   LOG     ensure log path
#   PIN_CMD optional command/script run each pass (e.g. edge hosts pin)
#   UP_CMD  optional start/respawn command when process gone or after kill
#
# Restart if: process gone (and UP_CMD set), local ha==0, OR zombie
# (local ha>=1 but `cloudflared tunnel info` shows 0 connectors).
# Kills ONLY the cloudflared process for this CFG — never other tunnels.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# Load site inventory (no secrets): SITE_ENV or $DIR/site.env|inventory.env
_load_site() {
  local f="" line key val
  if [[ -n "${SITE_ENV:-}" && -f "${SITE_ENV}" ]]; then f="${SITE_ENV}"
  elif [[ -f "$DIR/site.env" ]]; then f="$DIR/site.env"
  elif [[ -f "$DIR/inventory.env" ]]; then f="$DIR/inventory.env"
  elif [[ -f ./site.env ]]; then f=./site.env
  elif [[ -f ./inventory.env ]]; then f=./inventory.env
  fi
  [[ -n "$f" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
      key="${BASH_REMATCH[2]}"; val="${BASH_REMATCH[3]}"
      if [[ "$val" =~ ^\"(.*)\"$ ]]; then val="${BASH_REMATCH[1]}"; fi
      if [[ "$val" =~ ^\'(.*)\'$ ]]; then val="${BASH_REMATCH[1]}"; fi
      case "$key" in
        HOSTNAME|TUNNEL_ID|TUNNEL_NAME|ORIGIN_PORT|LISTEN_PORT|CFG|AUTH_FILE|ROLE|CFD|ACCESS_APP_URL|NOTES|METRICS_URL)
          if [[ -n "$val" ]]; then
            if [[ -z "${!key:-}" ]]; then
              printf -v "$key" '%s' "$val"; export "$key"
            elif [[ "$key" == "HOSTNAME" ]]; then
              _sys="$(hostname 2>/dev/null || true)"
              if [[ "${!key}" == "$_sys" || "${!key}" == "${_sys%%.*}" ]]; then
                printf -v "$key" '%s' "$val"; export "$key"
              fi
            fi
          fi
          ;;
      esac
    fi
  done <"$f"
}
_load_site
CFG="${CFG:-$HOME/.cloudflared/tunnel.yml}"
TUNNEL_ID="${TUNNEL_ID:?set TUNNEL_ID to the named tunnel UUID (or put it in site.env)}"
CFD="${CFD:-$HOME/.local/bin/cloudflared}"
LOG="${LOG:-$DIR/run/tunnel-ensure.log}"
PIN_CMD="${PIN_CMD:-}"
UP_CMD="${UP_CMD:-}"
mkdir -p "$(dirname "$LOG")"

if [[ -n "${PIN_CMD}" ]]; then
  bash -c "${PIN_CMD}" >>"$LOG" 2>&1 || true
fi

# Prefer the real cloudflared binary pid (exclude bash while-loop wrappers).
pid=""
while read -r p; do
  comm=$(ps -p "$p" -o comm= 2>/dev/null | tr -d ' ')
  if [[ "$comm" == *cloudflared* ]]; then pid=$p; break; fi
done < <(pgrep -f "cloudflared tunnel .*--config ${CFG}" || true)

if [[ -z "${pid}" ]]; then
  echo "$(date -Is) cloudflared down -> UP_CMD" >>"$LOG"
  if [[ -n "${UP_CMD}" ]]; then
    bash -c "${UP_CMD}" >>"$LOG" 2>&1 || true
  fi
  exit 0
fi

metrics_port=""
if command -v ss >/dev/null 2>&1; then
  metrics_port=$(ss -ltnp 2>/dev/null | grep "pid=${pid}," | grep -oE '127\.0\.0\.1:202[0-9]+' | head -1 | cut -d: -f2 || true)
fi

ha=""
if [[ -n "${metrics_port}" ]]; then
  ha=$(curl -fsS --max-time 2 "http://127.0.0.1:${metrics_port}/metrics" 2>/dev/null \
    | awk '/^cloudflared_tunnel_ha_connections /{print int($2)}' || true)
fi

# Authoritative: connectors reported by Cloudflare (via local cert).
cf_connectors=""
if [[ -x "$CFD" ]]; then
  info_out=$("$CFD" tunnel info "$TUNNEL_ID" 2>/dev/null || true)
  # Data rows look like UUID timestamps; header has CONNECTOR ID
  cf_connectors=$(printf '%s\n' "$info_out" | awk 'BEGIN{c=0} /^[0-9a-f]{8}-[0-9a-f]{4}-/{c++} END{print c}')
fi

zombie=0
if [[ -n "${ha}" && "${ha}" -ge 1 && -n "${cf_connectors}" && "${cf_connectors}" -lt 1 ]]; then
  zombie=1
fi

if [[ -z "${ha}" && -z "${cf_connectors}" ]]; then
  echo "$(date -Is) pid=${pid} port=${metrics_port:-unknown} ha=unreadable cf=unreadable (no action)" >>"$LOG"
  exit 0
fi

need_restart=0
reason=""
if [[ -n "${ha}" && "${ha}" -lt 1 ]]; then
  need_restart=1
  reason="ha=${ha}"
elif [[ "${zombie}" -eq 1 ]]; then
  need_restart=1
  reason="zombie local_ha=${ha} cf_connectors=0"
elif [[ -z "${ha}" && -n "${cf_connectors}" && "${cf_connectors}" -lt 1 ]]; then
  need_restart=1
  reason="cf_connectors=0"
fi

if [[ "${need_restart}" -eq 1 ]]; then
  echo "$(date -Is) pid=${pid} port=${metrics_port:-unknown} ${reason} -> kill cloudflared (wrapper/UP_CMD may respawn)" >>"$LOG"
  kill "$pid" 2>/dev/null || true
  sleep 3
  if [[ -n "${UP_CMD}" ]] && ! pgrep -f "cloudflared tunnel .*--config ${CFG}" >/dev/null; then
    bash -c "${UP_CMD}" >>"$LOG" 2>&1 || true
  fi
else
  echo "$(date -Is) ok pid=${pid} port=${metrics_port:-unknown} ha=${ha:-na} cf_connectors=${cf_connectors:-na}" >>"$LOG"
fi
