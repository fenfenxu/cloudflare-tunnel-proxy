# Cloudflare Tunnel Proxy

[![skills.sh](https://skills.sh/b/fenfenxu/cloudflare-tunnel-proxy)](https://skills.sh/fenfenxu/cloudflare-tunnel-proxy)

这是一份 **Agent Skill**（可被 [skills.sh](https://skills.sh) / `npx skills` 发现与安装）。方案以 skill 形式实现：助手按 **Setup / Doctor / Monitor** 带你搭、查、保活。

## 怎么安装（优先看这里）

不必先翻仓库源码。任选一种：

### 1）用 skills CLI（推荐；可进 skills.sh 生态）

需要本机有 Node.js（建议 22+）：

```bash
# 安装本 skill（交互里选代理即可）
npx skills add fenfenxu/cloudflare-tunnel-proxy

# 只看仓库里有哪些 skill、不安装
npx skills add fenfenxu/cloudflare-tunnel-proxy --list

# 指定 skill 名、全局安装、跳过确认（CI / 脚本）
npx skills add fenfenxu/cloudflare-tunnel-proxy --skill "Cloudflare Tunnel Proxy" -g -y
```

等价写法（完整 URL）：

```bash
npx skills add https://github.com/fenfenxu/cloudflare-tunnel-proxy
```

装好后，在支持 Agent Skills 的助手里直接说：「搭梯子」「doctor」「保活」即可。

发现页（安装量上来后会出现在 leaderboard；徽章点进去）：  
https://skills.sh/fenfenxu/cloudflare-tunnel-proxy

### 2）Grok Bot / 其它会读 GitHub skill 的助手

把仓库地址发给助手，让它按公开 skill 安装，例如：

> 从 https://github.com/fenfenxu/cloudflare-tunnel-proxy 安装 Cloudflare Tunnel Proxy skill，然后带我 Setup。

或只给 shorthand：`fenfenxu/cloudflare-tunnel-proxy`。

### 3）本机直接读仓库（开发 / 审阅）

```bash
git clone https://github.com/fenfenxu/cloudflare-tunnel-proxy.git
# 让助手读取仓库根目录的 SKILL.md（及 scripts/、templates/）
```

**安全提醒：** skill 含可执行脚本（`scripts/`、`templates/`）。安装前请浏览仓库；不要把 `proxy.auth`、密码写进聊天或公开 fork。

---

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
- 助手能从零 **Setup**（先检测 Clash 是否已装；验证后问是否改 Clash、先备份；谷歌打开确认后再问保活）、挂了时 **Doctor**、需要时 **Monitor** 保活
- 成功标准：技术探测 **HTTP 204** + 你确认浏览器能打开外网（如谷歌搜本 skill）
- 默认发布主机名形态：`cf-tunnel-proxy.<你的域名>`（DNS / Access / `cloudflared access tcp --hostname` 一致）

**你需要：** 免费 Cloudflare 账户、接到 Cloudflare 的自有域名、一台可常驻的翻墙机器。域名用支付宝 / 微信自行付款（助手不代付）。不能只用 `*.trycloudflare.com`。

**已知限制：** 出口常是 Cloudflare / 机房 IP，部分站点（如 OpenAI / Codex）可能不可用——不算搭建失败。图形客户端路径以 **Clash Verge Rev / mihomo** 为主；其它客户端未经本 skill 验收。

## 常见问题

**Access 登录会过期吗？**  
会。面板默认约 24 小时；Setup 会引导改成约 **7 天**（最长约一个月）。过期后在你的电脑上重新邮箱 OTP，再连一次即可；不等于翻墙机器坏了。

**OpenAI / Codex 打不开算失败吗？**  
不算。成功标准是探测地址返回 HTTP 204。

**为什么必须自己的域名？**  
稳定主机名和 Access 策略要绑在你自己的 zone 上；临时 trycloudflare 不在本方案里。

**密码会不会被写进聊天或仓库？**  
不应该。随机密码只放在翻墙机器本地的鉴权文件里，由你自己私密保存。

**域名快到期了要续费吗？**  
默认不引导续费原便宜域：到期前再买新域并迁过去，付款仍由你本人完成。

**没有 Clash 怎么办？**  
Skill 会检测；未装时推荐从 [Clash Verge Rev Releases](https://github.com/clash-verge-rev/clash-verge-rev/releases) 下载。坚持用其它客户端时，助手会说明该路径未验收、不一定能排通。

## 仓库结构（给审阅用）

| 路径 | 用途 |
|------|------|
| `SKILL.md` | 助手主流程（Setup / Doctor / Monitor） |
| `AUTHOR_LINKS.md` | 域名注册商官网 + Clash Verge Rev 下载出处 |
| `scripts/` | 预检、Doctor 分层探针 |
| `templates/` | 翻墙机器代理、ensure、Clash Merge 片段等 |

License：见 `LICENSE`。
