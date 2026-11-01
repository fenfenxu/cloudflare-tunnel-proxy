#!/usr/bin/env bash
# Layer: Access client token (optional if no cloudflared / HOSTNAME).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=doctor-common.sh
source "$DIR/doctor-common.sh"

layer_access() {
  local cfd tok exp now left
  if [[ -z "${HOSTNAME}" ]]; then
    doctor_result access SKIP "HOSTNAME unset"
    return 0
  fi
  if ! cfd=$(doctor_find_cfd); then
    doctor_result access SKIP "cloudflared not found"
    return 0
  fi
  tok=$("$cfd" access token -app "https://${HOSTNAME}" 2>/dev/null || true)
  if [[ -z "${tok}" ]]; then
    if pgrep -f "cloudflared access tcp" >/dev/null 2>&1 || [[ "${ACCESS_REQUIRED:-0}" == "1" ]]; then
      doctor_result access FAIL "no token (OTP/login needed?)"
      return 1
    fi
    doctor_result access SKIP "no token（翻墙机器上常见；或你的电脑尚未登录 OTP）"
    return 0
  fi
  exp=$(printf '%s' "$tok" | doctor_jwt_exp)
  now=$(date +%s)
  if [[ -z "${exp}" ]]; then
    doctor_result access OK "token present exp=unparsed"
    return 0
  fi
  left=$((exp - now))
  if [[ "${left}" -le 0 ]]; then
    doctor_result access FAIL "token expired"
    return 1
  fi
  doctor_result access OK "token valid_for_s=${left}"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  layer_access
fi
