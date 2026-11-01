#!/usr/bin/env bash
# Preflight: can this client reach Cloudflare for Access/Tunnel setup?
# Does NOT fail solely because 1.1.1.1 is blocked.
# Last line: RESULT=CONTINUE|RETRY_AFTER_QUIT_PROXY|STOP_NO_CF_REACH
set -u

OS="$(uname -s 2>/dev/null || echo unknown)"
TEAM="${TEAM:-}"
TIMEOUT="${CURL_TIMEOUT:-8}"

have_fake_ip=0
have_proxy_env=0
cf_https_ok=0
dns_clean_cf=0
notes=()

say() { printf '%s\n' "$*"; }

is_fake_ip() {
  # Clash fake-ip range 198.18.0.0/15
  case "$1" in
    198.18.*|198.19.*) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_ipv4() {
  local host="$1" out=""
  if command -v dig >/dev/null 2>&1; then
    out="$(dig +short +time=3 +tries=1 A "$host" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -5)"
  fi
  if [[ -z "$out" ]] && command -v getent >/dev/null 2>&1; then
    out="$(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | head -5)"
  fi
  if [[ -z "$out" ]] && command -v host >/dev/null 2>&1; then
    out="$(host -t A "$host" 2>/dev/null | awk '/has address/{print $NF}' | head -5)"
  fi
  if [[ -z "$out" ]] && command -v python3 >/dev/null 2>&1; then
    out="$(python3 -c "import socket; print('\\n'.join(sorted({ai[4][0] for ai in socket.getaddrinfo('$host', 443, socket.AF_INET)})))" 2>/dev/null || true)"
  fi
  printf '%s\n' "$out"
}

check_https() {
  local url="$1"
  # Do not use curl -f: 401/403/404 still mean Cloudflare answered.
  local code
  code="$(curl -sS --max-time "$TIMEOUT" -o /dev/null -w '%{http_code}' "$url" 2>/dev/null || true)"
  if [[ -z "$code" || "$code" == "000" ]]; then
    echo "fail"
  else
    echo "$code"
  fi
}

# --- 1) Env proxy detection ---
for v in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do
  if [[ -n "${!v:-}" ]]; then
    have_proxy_env=1
    notes+=("env $v=${!v}")
  fi
done

# --- 2) Optional macOS hints ---
if [[ "$OS" == "Darwin" ]]; then
  if command -v networksetup >/dev/null 2>&1; then
    # Best-effort: check common services for web proxy enabled
    while IFS= read -r svc; do
      [[ -z "$svc" ]] && continue
      info="$(networksetup -getwebproxy "$svc" 2>/dev/null || true)"
      if printf '%s' "$info" | grep -qi 'Enabled: Yes'; then
        have_proxy_env=1
        notes+=("macos webproxy on: $svc")
      fi
      info="$(networksetup -getsecurewebproxy "$svc" 2>/dev/null || true)"
      if printf '%s' "$info" | grep -qi 'Enabled: Yes'; then
        have_proxy_env=1
        notes+=("macos securewebproxy on: $svc")
      fi
      info="$(networksetup -getsocksfirewallproxy "$svc" 2>/dev/null || true)"
      if printf '%s' "$info" | grep -qi 'Enabled: Yes'; then
        have_proxy_env=1
        notes+=("macos socks on: $svc")
      fi
    done < <(networksetup -listallnetworkservices 2>/dev/null | tail -n +2 || true)
  fi
  # Clash / Verge process hints (not definitive)
  if pgrep -if 'Clash|clash-verge|ClashX|mihomo' >/dev/null 2>&1; then
    notes+=("macos: Clash-like process running — quit fully before judging network")
  fi
fi

# --- 3) DNS for Cloudflare-related hosts ---
hosts_to_check=(cloudflare.com dash.cloudflare.com one.dash.cloudflare.com)
if [[ -n "$TEAM" ]]; then
  hosts_to_check+=("${TEAM}.cloudflareaccess.com")
fi
# cloudflareaccess.com apex often 404 on HTTPS; still check DNS
hosts_to_check+=(cloudflareaccess.com)

fake_hosts=()
clean_hosts=()
for h in "${hosts_to_check[@]}"; do
  ips="$(resolve_ipv4 "$h" | tr '\n' ' ')"
  ips_trimmed="$(echo "$ips" | xargs)"
  if [[ -z "$ips_trimmed" ]]; then
    notes+=("dns empty: $h")
    continue
  fi
  bad=0
  for ip in $ips_trimmed; do
    if is_fake_ip "$ip"; then
      bad=1
      have_fake_ip=1
    fi
  done
  if [[ $bad -eq 1 ]]; then
    fake_hosts+=("$h->$ips_trimmed")
    notes+=("FAKE-IP dns: $h -> $ips_trimmed")
  else
    clean_hosts+=("$h->$ips_trimmed")
    # Count dash/one/cloudflare.com as CF-relevant clean DNS
    case "$h" in
      cloudflare.com|dash.cloudflare.com|one.dash.cloudflare.com|*.cloudflareaccess.com|cloudflareaccess.com)
        dns_clean_cf=1
        ;;
    esac
    # bash case won't match *. with literal; set if any clean CF host
    if [[ "$h" == *cloudflare* ]]; then
      dns_clean_cf=1
    fi
  fi
done

# --- 4) HTTPS reach (not 1.1.1.1) ---
# Any success among these is enough for CONTINUE
https_targets=(
  "https://one.dash.cloudflare.com"
  "https://dash.cloudflare.com"
  "https://www.cloudflare.com"
  "https://cloudflare.com"
)
if [[ -n "$TEAM" ]]; then
  https_targets+=("https://${TEAM}.cloudflareaccess.com")
fi

https_results=()
for url in "${https_targets[@]}"; do
  code="$(check_https "$url")"
  https_results+=("$url=>$code")
  # Treat 2xx/3xx/401/403 as "reachable" (CF answered)
  case "$code" in
    2??|3??|401|403|404) cf_https_ok=1 ;;
  esac
done

# Optional TCP 443 to cloudflare.com
tcp_ok=0
if command -v nc >/dev/null 2>&1; then
  if nc -z -w 3 cloudflare.com 443 >/dev/null 2>&1; then
    tcp_ok=1
    notes+=("tcp 443 cloudflare.com: open")
  else
    notes+=("tcp 443 cloudflare.com: closed/timeout")
  fi
elif command -v timeout >/dev/null 2>&1; then
  if timeout 3 bash -c 'echo >/dev/tcp/cloudflare.com/443' 2>/dev/null; then
    tcp_ok=1
    notes+=("tcp 443 cloudflare.com: open")
  else
    notes+=("tcp 443 cloudflare.com: closed/timeout")
  fi
fi

# Optional: 1.1.1.1 informational only
ones_note="skip"
if command -v curl >/dev/null 2>&1; then
  c111="$(curl -fsS --max-time 3 -o /dev/null -w '%{http_code}' https://1.1.1.1/cdn-cgi/trace 2>/dev/null || echo fail)"
  ones_note="https://1.1.1.1 => $c111 (informational only; must NOT decide RESULT)"
fi

# --- Decide RESULT ---
result=""
summary_zh=""
summary_en=""

if [[ $have_fake_ip -eq 1 ]]; then
  result="RETRY_AFTER_QUIT_PROXY"
  summary_zh="检测到 Clash 风格 fake-ip（198.18.0.0/15）污染 Cloudflare 相关 DNS。请完全退出 Clash/TUN/系统代理后重跑，不要据此判定网络不可用。"
  summary_en="Fake-ip (198.18.0.0/15) polluted Cloudflare DNS. Quit Clash/TUN/system proxy fully and re-run; do not judge the network yet."
elif [[ $cf_https_ok -eq 0 && $have_proxy_env -eq 1 ]]; then
  result="RETRY_AFTER_QUIT_PROXY"
  summary_zh="检测到环境/系统代理，且 HTTPS 访问 Cloudflare 失败。请关掉代理与 TUN 后重跑预检。"
  summary_en="Proxy env/system proxy set and Cloudflare HTTPS failed. Disable proxy/TUN and re-run."
elif [[ $cf_https_ok -eq 1 ]]; then
  result="CONTINUE"
  summary_zh="Cloudflare 可达，DNS 未见 fake-ip。可以继续注册/接入域名与搭 Tunnel+Access。"
  summary_en="Cloudflare reachable; no fake-ip DNS. Safe to continue CF/domain/tunnel setup."
elif [[ $dns_clean_cf -eq 1 && $cf_https_ok -eq 0 ]]; then
  result="STOP_NO_CF_REACH"
  summary_zh="DNS 已干净但仍无法 HTTPS 访问 Cloudflare。当前网络到 CF 不通，本方案应停止。"
  summary_en="DNS looks clean but Cloudflare HTTPS unreachable. Stop this approach on this network."
else
  # No clean DNS and no HTTPS — if proxy hints, retry; else stop
  if [[ $have_proxy_env -eq 1 ]]; then
    result="RETRY_AFTER_QUIT_PROXY"
    summary_zh="无法解析/访问 Cloudflare，且存在代理痕迹。请退出本地代理后重试。"
    summary_en="Cannot resolve/reach Cloudflare with proxy hints present. Quit local proxy and retry."
  else
    result="STOP_NO_CF_REACH"
    summary_zh="无法解析或访问 Cloudflare（非 fake-ip）。当前网络不适合本方案。"
    summary_en="Cannot resolve or reach Cloudflare (not fake-ip). Network not suitable."
  fi
fi

# --- Human report ---
say "=== cf-box-proxy preflight ==="
say "os=$OS team=${TEAM:-none}"
say "proxy_env_or_macos=$have_proxy_env fake_ip=$have_fake_ip cf_https_ok=$cf_https_ok dns_clean_cf=$dns_clean_cf tcp443=$tcp_ok"
say "1.1.1.1_check: $ones_note"
if ((${#clean_hosts[@]})); then say "dns_clean: ${clean_hosts[*]}"; fi
if ((${#fake_hosts[@]})); then say "dns_fake: ${fake_hosts[*]}"; fi
say "https: ${https_results[*]}"
if ((${#notes[@]})); then
  say "notes:"
  for n in "${notes[@]}"; do say "  - $n"; done
fi
say "ZH: $summary_zh"
say "EN: $summary_en"
say "RESULT=$result"
