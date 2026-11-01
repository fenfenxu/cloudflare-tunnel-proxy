#!/usr/bin/env bash
# Layer: local cloudflared tunnel ha_connections.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=doctor-common.sh
source "$DIR/doctor-common.sh"

layer_tunnel_ha() {
  local ha url
  if ! url=$(doctor_auto_metrics_url 2>/dev/null); then
    # no metrics: still check process
    if pgrep -f "cloudflared tunnel" >/dev/null 2>&1; then
      doctor_result tunnel_ha SKIP "process up metrics unavailable"
      return 0
    fi
    doctor_result tunnel_ha FAIL "no cloudflared tunnel process"
    return 1
  fi
  ha=$(curl -fsS --max-time 2 "${url}" 2>/dev/null \
    | awk '/^cloudflared_tunnel_ha_connections /{print int($2); exit}' || true)
  if [[ -z "${ha}" ]]; then
    doctor_result tunnel_ha SKIP "ha unreadable url=${url}"
    return 0
  fi
  if [[ "${ha}" -lt 1 ]]; then
    doctor_result tunnel_ha FAIL "ha=${ha}"
    return 1
  fi
  doctor_result tunnel_ha OK "ha=${ha}"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  layer_tunnel_ha
fi
