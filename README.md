# Cloudflare Tunnel Proxy

这是一份 **Agent Skill**。方案以 skill 形式实现：助手按 Setup / Doctor / Monitor 带你搭、查、保活。

## 解决什么问题

你想自己掌控一条个人翻墙 / 代理链路，而不是再买一个商业 VPN 账号：用 Cloudflare 命名隧道，把一台能访问外网的「翻墙机器」接到你自己的电脑上。

```
你的电脑（Clash / cloudflared access tcp）
  → Cloudflare 命名隧道
  → 翻墙机器上的本机代理（只绑 127.0.0.1）
  → 从翻墙机器出口访问外网
```

进隧道前要用 Cloudflare Access 邮箱 OTP 登录（身份门禁，不是网络多跳一截）。

## 你会得到什么

- 一条你自己掌控的代理：域名、Access 邮箱、翻墙机器都在你手里
- 助手能从零 **Setup**（验证后问是否改 Clash、先备份；谷歌打开确认后再问保活）、挂了时 **Doctor**、需要时 **Monitor** 保活
- 成功标准：技术探测 **HTTP 204** + 你确认浏览器能打开外网（如谷歌搜本 skill）
- 默认发布主机名形态：`cf-tunnel-proxy.<你的域名>`（DNS / Access / `cloudflared access tcp --hostname` 一致）

**你需要：** 免费 Cloudflare 账户、接到 Cloudflare 的自有域名、一台可常驻的翻墙机器。域名用支付宝 / 微信自行付款（助手不代付）。不能只用 `*.trycloudflare.com`。

**已知限制：** 出口常是 Cloudflare / 机房 IP，部分站点（如 OpenAI / Codex）可能不可用——不算搭建失败。

## 常见问题

**Access 登录会过期吗？**  
会。常见大约 24 小时。过期后在你的电脑上重新邮箱 OTP，再连一次即可；不等于翻墙机器坏了。

**OpenAI / Codex 打不开算失败吗？**  
不算。成功标准是探测地址返回 HTTP 204。

**为什么必须自己的域名？**  
稳定主机名和 Access 策略要绑在你自己的 zone 上；临时 trycloudflare 不在本方案里。

**密码会不会被写进聊天或仓库？**  
不应该。随机密码只放在翻墙机器本地的鉴权文件里，由你自己私密保存。

**域名快到期了要续费吗？**  
默认不引导续费原便宜域：到期前再买新域并迁过去，付款仍由你本人完成。

把本仓库交给支持 skill 的助手（或让它读 `SKILL.md`），直接说「搭梯子」「doctor」或「保活」即可。
