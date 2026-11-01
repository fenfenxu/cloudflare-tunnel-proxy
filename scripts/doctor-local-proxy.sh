#!/usr/bin/env bash
# Layer: local_proxy — 翻墙机器上 CONNECT generate_204（读 AUTH_FILE；不回显密钥）。
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=doctor-common.sh
source "$DIR/doctor-common.sh"

layer_local_proxy() {
  local auth code listen
  # 你的电脑上不应硬判翻墙机器 CONNECT；ROLE=client 时跳过，避免误报 down
  if [[ "${ROLE:-auto}" == "client" ]]; then
    doctor_result local_proxy SKIP "ROLE=client（CONNECT 在翻墙机器；请在翻墙机器上查或设 ROLE=host）"
    return 0
  fi
  listen=$(ss -ltn 2>/dev/null | awk -v p=":${ORIGIN_PORT}" '$4 ~ p {print $4; exit}' || true)
  if [[ -z "${listen}" ]] && command -v lsof >/dev/null 2>&1; then
    listen=$(lsof -nP -iTCP:"${ORIGIN_PORT}" -sTCP:LISTEN 2>/dev/null | awk 'NR==2{print $9; exit}' || true)
  fi
  if [[ -z "${listen}" ]]; then
    doctor_result local_proxy FAIL "翻墙机器上 :${ORIGIN_PORT} 无监听（若在你的电脑上跑，请设 ROLE=client）"
    return 1
  fi
  if [[ "${listen}" != *127.0.0.1* && "${listen}" != *\[::1\]* ]]; then
    # warn but continue — still try 127.0.0.1
    :
  fi
  if ! auth=$(doctor_read_auth "${AUTH_FILE}"); then
    doctor_result local_proxy FAIL "AUTH_FILE missing path=${AUTH_FILE}"
    return 1
  fi
  code=$(curl -sS -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 25 \
    -x "http://${auth}@127.0.0.1:${ORIGIN_PORT}" \
    https://www.google.com/generate_204 || echo "000")
  unset auth
  if [[ "${code}" == "204" ]]; then
    doctor_result local_proxy OK "generate_204=${code} listen=${listen}"
    return 0
  fi
  doctor_result local_proxy FAIL "generate_204=${code} listen=${listen}"
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  layer_local_proxy
fi
