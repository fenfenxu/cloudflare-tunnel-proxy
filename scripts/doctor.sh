#!/usr/bin/env bash
# Cloudflare Tunnel Proxy · Doctor light check (orchestrator).
# Env: HOSTNAME TUNNEL_ID ORIGIN_PORT AUTH_FILE METRICS_URL CFD CFG ACCESS_E2E
# Exit 0 only if light-check layers that matter are healthy enough.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=doctor-common.sh
source "$DIR/doctor-common.sh"
# shellcheck source=doctor-access.sh
source "$DIR/doctor-access.sh"
# shellcheck source=doctor-cf.sh
source "$DIR/doctor-cf.sh"
# shellcheck source=doctor-tunnel-ha.sh
source "$DIR/doctor-tunnel-ha.sh"
# shellcheck source=doctor-origin.sh
source "$DIR/doctor-origin.sh"
# shellcheck source=doctor-e2e.sh
source "$DIR/doctor-e2e.sh"
# shellcheck source=doctor-clash-ipv6.sh
source "$DIR/doctor-clash-ipv6.sh"

fail_hard=0
fail_soft=0
skip_n=0
declare -a LINES=()

run_layer() {
  local name="$1" fn="$2" soft="${3:-0}"
  local out rc=0
  set +e
  out=$($fn 2>&1)
  rc=$?
  set -e
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    LINES+=("$line")
    if [[ "$line" == RESULT\ *\=SKIP* ]]; then
      skip_n=$((skip_n + 1))
    elif [[ "$line" == RESULT\ *\=FAIL* ]]; then
      if [[ "$soft" == "1" ]]; then
        fail_soft=$((fail_soft + 1))
      else
        fail_hard=$((fail_hard + 1))
      fi
    fi
  done <<<"$out"
  return 0
}

# Order: Access → CF → tunnel ha → origin → e2e → clash ipv6
# Soft: access / e2e / clash_ipv6 (client-side; may be absent on origin-only)
run_layer access layer_access 1
run_layer cf layer_cf 0
run_layer tunnel_ha layer_tunnel_ha 0
run_layer origin layer_origin 0
run_layer e2e layer_e2e 1
run_layer clash_ipv6 layer_clash_ipv6 1

status=OK
if [[ "${fail_hard}" -gt 0 ]]; then
  status=down
elif [[ "${fail_soft}" -gt 0 ]]; then
  status=degraded
fi

echo "status=${status}"
for line in "${LINES[@]}"; do
  echo "$line"
done
echo "summary fail_hard=${fail_hard} fail_soft=${fail_soft} skip=${skip_n}"

if [[ "${status}" == "OK" ]]; then
  exit 0
fi
# light check: exit 0 only when end-to-end healthy enough → OK only
exit 1
