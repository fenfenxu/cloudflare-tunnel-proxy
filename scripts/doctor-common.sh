#!/usr/bin/env bash
# Shared helpers for doctor-*.sh. Sourced only; not run directly.
# Env (optional): HOSTNAME TUNNEL_ID ORIGIN_PORT AUTH_FILE METRICS_URL CFD CFG ROLE
# ROLE=auto|client|host — client=你的电脑 host=翻墙机器（见 SKILL 用语）
# Site inventory: SITE_ENV or ./site.env / AUTH_FILE sibling (see load-site-env.sh)

_DOC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=load-site-env.sh
source "$_DOC_DIR/load-site-env.sh"
ctp_load_site_env

: "${ORIGIN_PORT:=17897}"
: "${AUTH_FILE:=./proxy.auth}"
: "${CFD:=${HOME}/.local/bin/cloudflared}"
: "${HOSTNAME:=}"
: "${TUNNEL_ID:=}"
: "${METRICS_URL:=}"
: "${CFG:=}"

doctor_find_cfd() {
  if [[ -x "${CFD}" ]]; then
    printf '%s\n' "${CFD}"
    return 0
  fi
  if command -v cloudflared >/dev/null 2>&1; then
    command -v cloudflared
    return 0
  fi
  return 1
}

doctor_read_auth() {
  # prints user:pass to stdout once; caller must not log it
  local f="${1:-$AUTH_FILE}"
  if [[ ! -f "$f" ]]; then
    return 1
  fi
  tr -d '\n\r' <"$f"
}

doctor_auto_metrics_url() {
  if [[ -n "${METRICS_URL}" ]]; then
    printf '%s\n' "${METRICS_URL}"
    return 0
  fi
  local pid="" p port
  if [[ -n "${CFG}" ]]; then
    while read -r p; do
      local comm
      comm=$(ps -p "$p" -o comm= 2>/dev/null | tr -d ' ')
      if [[ "$comm" == *cloudflared* ]]; then pid=$p; break; fi
    done < <(pgrep -f "cloudflared tunnel .*--config ${CFG}" 2>/dev/null || true)
  fi
  if [[ -z "${pid}" ]]; then
    while read -r p; do
      local comm
      comm=$(ps -p "$p" -o comm= 2>/dev/null | tr -d ' ')
      if [[ "$comm" == *cloudflared* ]]; then pid=$p; break; fi
    done < <(pgrep -f "cloudflared tunnel" 2>/dev/null || true)
  fi
  [[ -n "${pid}" ]] || return 1
  if command -v ss >/dev/null 2>&1; then
    port=$(ss -ltnp 2>/dev/null | grep "pid=${pid}," | grep -oE '127\.0\.0\.1:202[0-9]+' | head -1 | cut -d: -f2 || true)
  else
    port=""
  fi
  [[ -n "${port}" ]] || return 1
  printf 'http://127.0.0.1:%s/metrics\n' "${port}"
}

doctor_local_ha() {
  local url ha
  url=$(doctor_auto_metrics_url) || return 1
  ha=$(curl -fsS --max-time 2 "${url}" 2>/dev/null \
    | awk '/^cloudflared_tunnel_ha_connections /{print int($2); exit}' || true)
  [[ -n "${ha}" ]] || return 1
  printf '%s\n' "${ha}"
}

doctor_cf_connectors() {
  # Prints connector count (may be 0). Returns 1 if tunnel info unreadable
  # (non-zero exit or missing NAME:/ID: header) — never print 0 on failure.
  local cfd tid info
  tid="${TUNNEL_ID:-}"
  [[ -n "${tid}" ]] || return 1
  cfd=$(doctor_find_cfd) || return 1
  if ! info=$("$cfd" tunnel info "$tid" 2>/dev/null); then
    return 1
  fi
  if ! printf '%s\n' "$info" | grep -qE '^(NAME:|ID:)'; then
    return 1
  fi
  printf '%s\n' "$info" | awk 'BEGIN{c=0} /^[0-9a-f]{8}-[0-9a-f]{4}-/{c++} END{print c}'
}
doctor_jwt_exp() {
  # stdin: JWT; stdout: exp epoch or empty
  python3 - <<'PY' 2>/dev/null || true
import sys, json, base64
tok = sys.stdin.read().strip()
if not tok or tok.count(".") < 2:
    sys.exit(0)
payload = tok.split(".")[1]
payload += "=" * ((4 - len(payload) % 4) % 4)
try:
    data = json.loads(base64.urlsafe_b64decode(payload))
except Exception:
    sys.exit(0)
exp = data.get("exp")
if exp is not None:
    print(int(exp))
PY
}

doctor_result() {
  # doctor_result LAYER CODE detail...
  local layer="$1" code="$2"
  shift 2
  printf 'RESULT %s=%s' "$layer" "$code"
  if [[ "$#" -gt 0 ]]; then
    printf ' %s' "$*"
  fi
  printf '\n'
}
