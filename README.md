# Cloudflare Tunnel Proxy

Personal proxy skill: **Cloudflare Tunnel + Access TCP** → 翻墙机器 localhost CONNECT → 你的电脑 Clash / `cloudflared access tcp`.

用语（对用户）：

| 用语 | 指什么 |
|------|--------|
| **你的电脑** | Clash / `cloudflared access tcp` 客户端（常见 Mac） |
| **翻墙机器** | 常驻 CONNECT 代理 + Cloudflare 命名隧道的那台 |

One skill, three modes:

| Mode | When |
|------|------|
| **Setup** | First-time 翻墙 / 梯子 / CF proxy install |
| **Doctor** | `doctor` / health / 挂了 / diagnose + repair (incl. zombie tunnels); set `ROLE=client` on 你的电脑 or `ROLE=host` on 翻墙机器 |
| **Monitor** | Keepalive / routine that runs Doctor and auto-fixes when possible |

## Layout

- `SKILL.md` — agent recipe (load in Grok Bot / Cursor skills)
- `scripts/` — preflight + Doctor (`RESULT` keys: `access` / `cf` / `tunnel_ha` / `local_proxy` / `e2e` / `clash_ipv6`)
- `templates/` — 翻墙机器 CONNECT proxy + ensure scripts
- `AUTHOR_LINKS.md` — Alipay/WeChat-friendly registrars (no affiliate links)
- `box-connect-proxy.md` — short 翻墙机器 deploy notes

Hard requirement: a domain on Cloudflare (not `trycloudflare` alone).

After Setup succeeds, assistants that support routines (e.g. Grok Bot) should ask whether to add a Monitor routine.
