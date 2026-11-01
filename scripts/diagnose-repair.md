# Cloudflare Tunnel Proxy 诊断与修复清单

用语同 skill：**你的电脑** = Clash / access tcp 客户端；**翻墙机器** = CONNECT + 命名隧道所在机。RESULT 键：`access` / `cf` / `tunnel_ha` / `local_proxy` / `e2e` / `clash_ipv6`。
配合 skill **I 节**。可执行轻检：`scripts/doctor.sh`（见 I3）。占位符：`cf-tunnel-proxy.<domain>`、`<PORT>`、`USER:PASS`、`<TUNNEL_UUID>`。

## 1. 翻墙机器 CONNECT（local_proxy）

```bash
ss -ltnp | rg "<PORT>|gost|connect_proxy"
curl -o /dev/null -w '%{http_code}\n' -x "http://USER:PASS@127.0.0.1:<PORT>" \
  https://www.google.com/generate_204
# expect 204
```

## 2. Tunnel：本地 vs Cloudflare（防假活）

本地：

```bash
pgrep -af 'cloudflared tunnel'
# metrics 端口常见 20241+
curl -fsS "http://127.0.0.1:<METRICS>/metrics" | awk '/^cloudflared_tunnel_ha_connections /{print}'
```

权威（API 或面板）：tunnel `status` 必须为 `healthy`，`connections` 非空。

**假活：** 本地 ha≥1 且 API `down`/空连接 → 杀掉该配置对应的 cloudflared，让 wrapper 拉起；再查 API 至 healthy。

## 3. DNS / ingress

- CNAME `cf-tunnel-proxy.<domain>` → `<TUNNEL_UUID>.cfargotunnel.com`（Proxied）
- ingress：`cf-tunnel-proxy.<domain>` → `tcp://127.0.0.1:<PORT>`
- 建议 `protocol: http2`；edge 勿解析成 `198.18.0.0/15`

## 4. Access + 你的电脑

```bash
cloudflared access token -app https://cf-tunnel-proxy.<domain>   # 有 JWT
# 日志若持续 websocket: bad handshake → 先排除假活与 Clash 套娃
launchctl kickstart -k "gui/$(id -u)/<access-tcp-label>"  # macOS 保活时
```

Clash：节点 = 本机 PORT + Basic auth；`cloudflared` 与 `cf-tunnel-proxy.<domain>` DIRECT。

## 5. 端到端

```bash
curl -o /dev/null -w '%{http_code}\n' -x "http://USER:PASS@127.0.0.1:<PORT>" \
  https://www.google.com/generate_204
# 204 = 修好；只报「进程在」不算完成
```


## Clash TUN IPv6 套娃（Mac 常见）

症状：`websocket: bad handshake`；DNS 解析为真实 CF IP、IPv4 `route-exclude` 已配、Access token 未过期、隧道 API `healthy`，裸 `curl` WebSocket 升级可能仍返回 101。

核对：

```bash
# cloudflared access tcp 出站：若源是 fdfe:dcba:9876::1 / 目标 2606:4700:: → 被 TUN 劫持
lsof -nP -p "$(pgrep -f 'cloudflared access tcp' | head -1)" | grep -E 'TCP|UDP'
```

修复：在 Clash Verge **Merge** 的 `tun.route-exclude-address` 加入 Cloudflare IPv6 段（至少 `2606:4700::/32`），热更新/重载后 `launchctl kickstart -k gui/$(id -u)/<access-tcp-label>`（或等价重启 access tcp）。成功时出站应类似 `192.168.x.x → 104.x/172.x:443`（en0 IPv4），端到端 `generate_204`=204。
