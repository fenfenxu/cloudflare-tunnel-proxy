# Cloudflare Tunnel Proxy

个人翻墙 / 代理方案：**用 Cloudflare 隧道，把一台能访问外网的「翻墙机器」接到你自己的电脑上。**

## 这套方案是什么

你要的不是「再买一个商业 VPN 账号」，而是一条**自己掌控**的个人代理链路：

1. 有一台能常开、能访问外网的机器（VPS、家里电脑、Bot 电脑等）——我们叫它 **翻墙机器**。
2. 在翻墙机器上只监听本机的一个小代理，再经 **Cloudflare 命名隧道** 发到你的域名。
3. 在你的电脑上用 `cloudflared access tcp`（可选 Clash）连这条隧道；用邮箱 OTP 登录 Cloudflare Access 鉴权。

合在一起，就是：

```
你的电脑（Clash / cloudflared access tcp）
  → Cloudflare Access（邮箱一次性验证码）
  → Cloudflare 命名隧道
  → 翻墙机器上的本机代理（只绑 127.0.0.1）
  → 从翻墙机器出口访问外网
```

**成功标准（给用户的一句话）：** 在你的电脑上，带鉴权访问探测地址返回 **HTTP 204**（例如 Google `generate_204`）。

### 用语（请始终用这两套词）

| 用语 | 指什么 |
|------|--------|
| **你的电脑** | 日常使用的客户端：Clash、`cloudflared access tcp`（常见是 Mac） |
| **翻墙机器** | 常驻跑「本机代理 + Cloudflare 命名隧道」的那台 |

不要对用户说 Origin / ingress 等内部词。

### 你需要具备什么

- 免费 Cloudflare 账户  
- **自己的域名**并接到 Cloudflare（不能只用 `*.trycloudflare.com`）  
- 一台可常驻的翻墙机器  
- 域名可用支付宝 / 微信等自行付款购买（助手不代付、不推联盟链接）

### 已知限制

出口 IP 常是 Cloudflare / 机房地址，**部分网站（如 OpenAI / Codex）可能不可用**——这是方案限制，不是安装失败。

### 三种用法

| 模式 | 什么时候 |
|------|----------|
| **Setup** | 从零搭梯子 / 翻墙 / CF 代理 |
| **Doctor** | 挂了、不通、health；分层查「你的电脑 / 翻墙机器」并尽量自动修 |
| **Monitor** | 保活：优先翻墙机器上的 cron/脚本；助手例程只做 OTP 等必须人工的兜底 |

## 仓库里有什么

- `SKILL.md` — 给助手用的完整配方（Grok Bot / Cursor skill）
- `scripts/` — 网络预检 + 分层 Doctor（`doctor.sh`）
- `templates/` — 翻墙机器上的代理与保活脚本
- `AUTHOR_LINKS.md` — 支持支付宝/微信的域名注册商官网（无联盟）
- `box-connect-proxy.md` — 翻墙机器部署短说明

更细的步骤、坑和修复表见 `SKILL.md`。
