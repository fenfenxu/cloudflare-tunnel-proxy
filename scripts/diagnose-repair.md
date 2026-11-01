# Cloudflare Tunnel Proxy 诊断与修复清单

配合 skill **I 节**。占位符：`proxy.<domain>`、`<PORT>`、`USER:PASS`、`<TUNNEL_UUID>`。

## 1. box CONNECT

```bash
ss -ltnp | rg "<PORT>|connect_proxy"
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

- CNAME `proxy.<domain>` → `<TUNNEL_UUID>.cfargotunnel.com`（Proxied）
- ingress：`proxy.<domain>` → `tcp://127.0.0.1:<PORT>`
- 建议 `protocol: http2`；edge 勿解析成 `198.18.0.0/15`

## 4. Access + 客户端

```bash
cloudflared access token -app https://proxy.<domain>   # 有 JWT
# 日志若持续 websocket: bad handshake → 先排除假活与 Clash 套娃
launchctl kickstart -k "gui/$(id -u)/<access-tcp-label>"  # macOS 保活时
```

Clash：节点 = 本机 PORT + Basic auth；`cloudflared` 与 `proxy.<domain>` DIRECT。

## 5. 端到端

```bash
curl -o /dev/null -w '%{http_code}\n' -x "http://USER:PASS@127.0.0.1:<PORT>" \
  https://www.google.com/generate_204
# 204 = 修好；只报「进程在」不算完成
```
