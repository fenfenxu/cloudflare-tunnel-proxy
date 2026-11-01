# Cloudflare Tunnel Proxy

Personal proxy skill: **Cloudflare Tunnel + Access TCP** → origin localhost CONNECT.

One skill, three modes:

| Mode | When |
|------|------|
| **Setup** | First-time 翻墙 / 梯子 / CF proxy install |
| **Doctor** | `doctor` / health / 挂了 / diagnose + repair (incl. zombie tunnels) |
| **Monitor** | Keepalive / routine that runs Doctor and auto-fixes when possible |

## Layout

- `SKILL.md` — agent recipe (load in Grok Bot / Cursor skills)
- `scripts/` — preflight + diagnose notes
- `templates/` — origin CONNECT proxy + ensure scripts
- `AUTHOR_LINKS.md` — Alipay/WeChat-friendly registrars (no affiliate links)
- `box-connect-proxy.md` — short origin deploy notes

Hard requirement: a domain on Cloudflare (not `trycloudflare` alone).

After Setup succeeds, assistants that support routines (e.g. Grok Bot) should ask whether to add a Monitor routine.
