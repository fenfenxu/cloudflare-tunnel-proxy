#!/usr/bin/env bash
# Layer: macOS Clash TUN IPv6 hijack of cloudflared access tcp (fdfe → 2606:4700).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=doctor-common.sh
source "$DIR/doctor-common.sh"

layer_clash_ipv6() {
  local os pid out
  os=$(uname -s 2>/dev/null || echo unknown)
  if [[ "${os}" != "Darwin" ]]; then
    doctor_result clash_ipv6 SKIP "not macOS"
    return 0
  fi
  if ! command -v lsof >/dev/null 2>&1; then
    doctor_result clash_ipv6 SKIP "lsof missing"
    return 0
  fi
  pid=$(pgrep -f "cloudflared access tcp" 2>/dev/null | head -1 || true)
  if [[ -z "${pid}" ]]; then
    doctor_result clash_ipv6 SKIP "no access tcp pid"
    return 0
  fi
  out=$(lsof -nP -p "${pid}" 2>/dev/null || true)
  if printf '%s\n' "$out" | grep -E 'fdfe:dcba|\[fdfe:' | grep -E '2606:4700' >/dev/null 2>&1; then
    doctor_result clash_ipv6 FAIL "access tcp via Clash TUN IPv6 (fdfe→2606:4700); add CF IPv6 to Merge tun.route-exclude-address (2606:4700::/32 etc.) then restart access tcp"
    return 1
  fi
  if printf '%s\n' "$out" | grep -E 'fdfe:dcba|\[fdfe:' >/dev/null 2>&1; then
    doctor_result clash_ipv6 FAIL "access tcp src looks like Clash TUN IPv6 (fdfe:...); exclude CF IPv6 in Merge"
    return 1
  fi
  doctor_result clash_ipv6 OK "no fdfe→2606:4700 seen on pid=${pid}"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  layer_clash_ipv6
fi
