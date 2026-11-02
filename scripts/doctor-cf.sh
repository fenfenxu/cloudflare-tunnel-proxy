#!/usr/bin/env bash
# Layer: Cloudflare tunnel connectors via `cloudflared tunnel info` (zombie cross-check).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=doctor-common.sh
source "$DIR/doctor-common.sh"

layer_cf() {
  local connectors ha
  if [[ -z "${TUNNEL_ID}" ]]; then
    doctor_result cf SKIP "TUNNEL_ID unset"
    return 0
  fi
  if ! doctor_find_cfd >/dev/null; then
    doctor_result cf SKIP "cloudflared not found"
    return 0
  fi
  # Empty = unreadable (doctor_cf_connectors returned 1); "0" = readable zero connectors.
  connectors=$(doctor_cf_connectors || true)
  if [[ -z "${connectors}" ]]; then
    doctor_result cf SKIP "tunnel info unreadable"
    return 0
  fi
  ha=$(doctor_local_ha 2>/dev/null || true)
  if [[ -n "${ha}" && "${ha}" -ge 1 && "${connectors}" -lt 1 ]]; then
    doctor_result cf FAIL "zombie local_ha=${ha} cf_connectors=0"
    return 1
  fi
  if [[ "${connectors}" -lt 1 ]]; then
    doctor_result cf FAIL "cf_connectors=0"
    return 1
  fi
  doctor_result cf OK "cf_connectors=${connectors}"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  layer_cf
fi
