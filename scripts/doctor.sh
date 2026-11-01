#!/usr/bin/env bash
# Cloudflare Tunnel Proxy · Doctor light check (orchestrator).
# Env: HOSTNAME TUNNEL_ID ORIGIN_PORT AUTH_FILE METRICS_URL CFD CFG ACCESS_E2E
#      ROLE=auto|client|host
#        client = 你的电脑（Clash / access tcp）
#        host   = 翻墙机器（CONNECT + named tunnel）
#        auto   = 旧行为（不按角色跳过；跨机器可能误报）
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
# shellcheck source=doctor-local-proxy.sh
source "$DIR/doctor-local-proxy.sh"
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

ROLE="${ROLE:-auto}"

# soft flags by role — avoid status=down from cross-machine misreads
soft_access=1
soft_e2e=1
soft_clash=1
soft_local=0
soft_ha=0
soft_cf=0
case "${ROLE}" in
  client)
    # 你的电脑：CONNECT / 本地 ha 在翻墙机器；层内会 SKIP，仍标 soft 兜底
    soft_local=1
    soft_ha=1
    soft_e2e=0
    soft_access=0
    ;;
  host)
    # 翻墙机器：客户端层 soft
    soft_access=1
    soft_e2e=1
    soft_clash=1
    soft_local=0
    soft_ha=0
    ;;
  auto|*)
    ;;
esac

# Order: access → cf → tunnel_ha → local_proxy → e2e → clash_ipv6
run_layer access layer_access "${soft_access}"
run_layer cf layer_cf "${soft_cf}"
run_layer tunnel_ha layer_tunnel_ha "${soft_ha}"
run_layer local_proxy layer_local_proxy "${soft_local}"
run_layer e2e layer_e2e "${soft_e2e}"
run_layer clash_ipv6 layer_clash_ipv6 "${soft_clash}"

status=OK
if [[ "${fail_hard}" -gt 0 ]]; then
  status=down
elif [[ "${fail_soft}" -gt 0 ]]; then
  status=degraded
fi

echo "status=${status}"
echo "role=${ROLE}"
for line in "${LINES[@]}"; do
  echo "$line"
done
echo "summary fail_hard=${fail_hard} fail_soft=${fail_soft} skip=${skip_n}"

if [[ "${status}" == "OK" ]]; then
  exit 0
fi
exit 1
