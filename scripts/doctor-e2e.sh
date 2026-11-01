#!/usr/bin/env bash
# Layer: e2e generate_204 via local access-tcp listener (same port when client-side).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=doctor-common.sh
source "$DIR/doctor-common.sh"

layer_e2e() {
  local auth code has_access=0
  # On origin box, CONNECT and access share the same port only on the client.
  # Skip if no access tcp process and we already validated origin separately,
  # unless ACCESS_E2E=1 forces the check.
  if pgrep -f "cloudflared access tcp" >/dev/null 2>&1; then
    has_access=1
  fi
  if [[ "${has_access}" -ne 1 && "${ACCESS_E2E:-0}" != "1" ]]; then
    doctor_result e2e SKIP "no access tcp process (origin-only host?)"
    return 0
  fi
  if ! auth=$(doctor_read_auth "${AUTH_FILE}"); then
    doctor_result e2e FAIL "AUTH_FILE missing"
    return 1
  fi
  code=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 25 \
    -x "http://${auth}@127.0.0.1:${ORIGIN_PORT}" \
    https://www.google.com/generate_204 || echo "000")
  unset auth
  if [[ "${code}" == "204" ]]; then
    doctor_result e2e OK "generate_204=${code}"
    return 0
  fi
  doctor_result e2e FAIL "generate_204=${code}"
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  layer_e2e
fi
