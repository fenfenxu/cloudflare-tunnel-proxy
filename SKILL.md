---
name: Cloudflare Tunnel Proxy
description: >-
  When the user wants to set up, diagnose (doctor/health), or monitor a personal
  Cloudflare Tunnel + Access TCP proxy—including colloquial asks about 翻墙, 梯子,
  代理, 隧道, CF, Cloudflare, Cloudflare梯子, Cloudflare翻墙代理, or a broken Clash CF
  node: route to Setup (A–H + offer keepalive routine), Doctor (I), or Monitor
  (J). Not for trycloudflare-only or domain-less paths. Do not mention
  affiliate/referral.
---
# Cloudflare Tunnel Proxy

## 用语

对用户说话、写 RESULT 说明、以及 Doctor/Monitor 话术时只用下面两套词，**不要**再用 Origin / origin 主机 这类外人听不懂的叫法：

| 用语 | 指什么 |
|------|--------|
| **你的电脑** | 跑 Clash / `cloudflared access tcp` 的客户端（常见是 Mac） |
| **翻墙机器** | 常驻跑「本地 CONNECT 代理 + Cloudflare 命名隧道」的那台（可以是 VPS、家里机器、Bot 电脑等） |

英文技术环境变量名（如 `AUTH_FILE`、`ORIGIN_PORT`、`TUNNEL_ID`）可保留；**RESULT 键名与对人说明**用白话：`access`、`cf`、`tunnel_ha`、`local_proxy`、`e2e`、`clash_ipv6`。

Doctor 要在**对应角色的机器**上解读：翻墙机器上查 `local_proxy` / 隧道进程；你的电脑上查 Access / access tcp / Clash。在你的电脑上跑 Doctor 却去判翻墙机器上的隧道进程 → 出现 FAIL 多半是**角色读错**，不是链路一定挂了（设 `ROLE=client` 或 `ROLE=host` 见 I3）。对用户复述时用「你的电脑 / 翻墙机器」，不要说 Origin。

---

## 这套方案是什么（先读再动手）

本 skill 描述的是一条**个人翻墙 / 代理产品**，不是零散命令清单。整体组合是：

**Cloudflare（域名 + Access + 命名隧道） + 一台能访问外网的翻墙机器 + 你的电脑上的客户端。**

角色分工：

1. **翻墙机器**：常开；只在 `127.0.0.1` 跑 CONNECT 代理；用 Cloudflare 命名隧道把 `proxy.<域名>` 指到这个本机端口；出口走这台机器的外网。
2. **Cloudflare**：免费账户 + **已接入的自有域名**（硬前提；`trycloudflare` / 无域名 = 不做）；Access 用邮箱 OTP 挡住陌生人；隧道负责把你的电脑连到翻墙机器，而不用把代理端口暴露到公网。
3. **你的电脑**：`cloudflared access tcp`（可选 Clash）连 `proxy.<域名>`；日常流量经这条链路出去。

链路（记熟，排障按此分层）：

```
你的电脑（Clash / cloudflared access tcp）
  → Cloudflare Access（邮箱 OTP）
  → Cloudflare 命名隧道
  → 翻墙机器上 127.0.0.1 CONNECT 代理
  → 翻墙机器出口访问外网
```

**给用户的成功标准：** 在你的电脑上带鉴权探测 → HTTP **204**。OpenAI 等不可用 = 已知出口限制，不算搭建失败。

**助手必须先建立这幅图再 Setup/Doctor/Monitor**，不要把用户拖进互不关联的面板操作。对人解释用「你的电脑 / 翻墙机器 / Cloudflare」三块；细节命令放在后文各节。

**硬前提：** Cloudflare 上要有 zone（域名）。`*.trycloudflare.com` / 无域名 / 无 Access TCP 主机名 = **NO-GO**。

助手专属细节（某人的邮箱、生产主机名、现成密码）**不要**写进本 skill；一律用占位符。把用户当普通新用户：不要假设已有 CF/域名/`cloudflared`/现成隧道。

**禁止**在本 skill、开场说明或对用户话术里提及联盟、返佣、referral、带货佣金；买域名只谈用户怎么付、付多少。

本 skill 是**一组能力**（一个入口、多种模式），先路由再动手：

| 模式 | 用户说法（例） | 去做 |
|------|----------------|------|
| **Setup** | 搭梯子 / 翻墙 / 装代理 / Cloudflare 隧道 / 从零 setup | A–H，装完再问是否挂 Monitor 例程 |
| **Doctor** | 挂了 / 不通 / 诊断 / doctor / health / healthy / 还通不通 | I，分层诊断与修复；不要从头重装 |
| **Monitor** | 保活 / 监控 / monitor / 定时检查 / 自动修 | J，优先 cron/保活脚本；例程仅 OTP 等兜底 |

不确定时：已有链路且在抱怨不通 → **Doctor**；否则 → **Setup**。

## A. Setup · 开场（短清单，禁止长文堆砌）

聊天里**不要**贴大段成本说明。用下面这种短结构，一眼看清「要具备什么 → 接下来做什么」。措辞要直白，**禁止**用含糊的「能上网」。

**要具备**
1. **本机网络能摸到 Cloudflare**（先完全退出 Clash / Verge / 其它 TUN，并关掉系统 HTTP/HTTPS/SOCKS 代理，再跑预检；通了才继续）
2. **一个 Cloudflare 账户**（没有可用邮箱**免费注册**；OTP 优先常用**个人邮箱**；临时邮箱常收不到注册商验证码）
3. **一个自己的完整域名**（没有也可现买；助手选便宜档，首年常约 **$1** 量级；付费用**支付宝或微信**扫码，用户本人付）
4. 接受：出口常是 CF / 机房 IP，**OpenAI / Codex 等可能不可用**（已知限制）

**接下来做什么**
1. 预检：本机能否访问 Cloudflare  
2. 注册/登录 Cloudflare（免费）  
3. 助手选一个便宜域名 → 你支付宝/微信付款 → NS 指到 CF  
4. 翻墙机器起本地代理 → 开隧道 + Access → 你的电脑装 `cloudflared` 验证  

一句问是否继续。不愿买域名或拒绝成本 → **硬停**（见 F）。

---

## B. Setup · 预检网络（先退出代理，再跑探针）

开场已要求退出代理后，在**你的电脑**（Mac 或 Linux）跑：

```bash
bash "<本 skill 目录>/scripts/preflight-cf-reach.sh"
# 可选：TEAM=yourteam bash .../preflight-cf-reach.sh
```

Skill 目录一般是：`/home/box/agent-data/workflows/cloudflare-tunnel-proxy/`  
拷到用户机器或拷出执行均可。仓库镜像：本仓库根目录即 skill 内容。

**不要**用「1.1.1.1 不通」单独判死刑。

---

## C. Setup · 解读探针结果

脚本最后一行：`RESULT=...`

| RESULT | 含义 | 助手动作 |
|--------|------|----------|
| `CONTINUE` | DNS 干净且能摸到 Cloudflare | 进入 D |
| `RETRY_AFTER_QUIT_PROXY` | 代理 / Clash TUN fake-ip（`198.18.0.0/15`）污染 | **再次**确认完全退出后重跑；未干净前不要判「网络不行」 |
| `STOP_NO_CF_REACH` | 干净网络仍摸不到 CF | **硬停** |

即使 `CONTINUE`，若仍看到会套娃的 Clash 主进程/TUN，OTP/装客户端前再确认已退；仅特权助手进程可记笔记，不要反复卡用户。

---

## D. Setup · 询问现状

1. 是否已有 **Cloudflare 账户**？  
2. 是否已有域名且 **已添加到 Cloudflare**（NS 已生效）？

若用户说「没有账户」，但保险库/浏览器里其实已有同邮箱登录：按**新注册流程**走，并口头说明「这个邮箱可能其实已有账户，登录页会提示」。不要静默复用他人生产隧道/主机名。

---

## E. Setup · 引导分支

### E1. 注册 Cloudflare（若无）

1. https://dash.cloudflare.com/sign-up  
2. **个人邮箱** + 密码；收 OTP（临时邮箱仅作备选，收不到就换个人邮箱）  
3. 不要编造任何「推荐注册」链接；只用官方注册页  

### E2. 买便宜域名并接入 Cloudflare（若无 zone / 或到期换新域）

#### 渠道规则

只提出并推荐结账支持 **支付宝和/或微信支付** 的注册商（见同目录 `AUTHOR_LINKS.md` 官网表）。默认优先 **Dynadot**（支付宝路径清晰）。

**不要**默认写成纯信用卡结账；结账走扫码，用户本人付。

#### 域名怎么买

**(a)** 助手**只生成一个**可用名并直接进入购买流程；**禁止**列出 3～5 个让用户挑。  
**(b)** 命名：短前缀 + 随机字母数字 + 便宜 TLD（优先促销 `.xyz` 等）；查注册商确认可注册且为首年低价档。  
**(c)** 找便宜档即可（开场可说约 **$1** 量级，以结算页为准）；**禁止引导续费**原域名——到期前再买新的便宜域并迁移，旧域弃用。

步骤：

1. 打开 `AUTHOR_LINKS.md` 里选定注册商的**官网**（不要臆造其它购买链）  
2. 生成**一个**名 → 查价可用 → 加入购物车  
3. **付款停点**：告诉用户金额与支付方式（支付宝/微信扫码），等用户本人付完再继续；不要代付  
4. 注册商账户邮箱优先个人邮箱；OTP 收不到 → 换个人邮箱或换表内其它渠道，勿空转  
5. 付完：Cloudflare → **Add a site** → Free → 改 NS → 等到 **Active**  
6. **换域迁移**（已有旧代理时）：新 zone Active 后，把隧道发布名、DNS CNAME、Access 域名、客户端 `--hostname` 全部改到 `proxy.<新域>`；`generate_204`=204 后再弃用旧域  

无域名且不愿买 → **硬停**。

### E3. 翻墙机器：本地 CONNECT 代理（只绑回环）

在隧道所在的 **翻墙机器**上部署（详见 `box-connect-proxy.md` 与 `templates/`）：

1. 目录自定（示例：`/workspace/network/cloudflare-tunnel-proxy/`）  
2. 复制 `templates/connect_proxy.py`、`start.sh`、`ensure.sh`、`stop.sh`  
3. 生成随机 Basic 鉴权（**不要**用文档示例密码）：

```bash
umask 077
USER=proxy
PASS="$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)"
printf '%s:%s\n' "$USER" "$PASS" > proxy.auth
chmod 600 proxy.auth
```

4. `./start.sh` 或 `./ensure.sh`；只监听 `127.0.0.1:<PORT>`（默认 `17897`），**禁止** `0.0.0.0`  
5. 把 `user:pass` 和端口告诉用户（私密保存）

### E4. Cloudflare：Named Tunnel + 发布 TCP 主机名

1. `cloudflared tunnel login`（授权到该 zone）  
2. `cloudflared tunnel create <tunnel-name>`  
3. ingress：`proxy.<domain>` → `tcp://127.0.0.1:<PORT>`  
4. 建议 `protocol: http2`  
5. DNS：CNAME `proxy` → `<TUNNEL_UUID>.cfargotunnel.com`（Proxied）  
6. `cloudflared tunnel run` + 保活；**不要**误杀同一主机上其它隧道  

面板：Zero Trust / Networks → Tunnels → Published application。

### E5. Access：应用 + 邮箱 OTP

1. https://one.dash.cloudflare.com/ → Zero Trust  
2. Access → Applications → 保护 `proxy.<domain>`  
3. Policy：Allow → 用户**个人邮箱**  
4. 启用 One-time PIN；会话过期后需重新 OTP  

### E6. 你的电脑：cloudflared access tcp（+ 可选 Clash）

假定你的电脑**尚未**安装 `cloudflared`（冷启动按新装验证；若已有则先卸再装亦可按用户环境）。

```bash
brew install cloudflare/cloudflare/cloudflared
# 或官方下载页

cloudflared access tcp --hostname proxy.<domain> --url 127.0.0.1:<PORT>
```

可选 Clash HTTP 节点：`127.0.0.1:<PORT>` + `proxy.auth`。**Clash 必须给 `cloudflared` 走 DIRECT**（域名 `proxy.<domain>`、`*.cloudflareaccess.com`、进程名均直连），且 Merge `tun.route-exclude-address` 排除 Cloudflare **IPv4+IPv6**（见 G），否则 Access WebSocket 会套娃或握手失败。

### E7. 验证成功标准

```bash
curl -o /dev/null -w '%{http_code}\n' \
  -x "http://USER:PASS@127.0.0.1:PORT" \
  https://www.google.com/generate_204
```

**成功：** HTTP **204**。OpenAI 失败 = 已知限制，不算搭建失败。

### E8. Setup 完成后：询问是否加 Monitor 例程

端到端 **204** 之后，**必须**用一两句话问用户要不要加保活/巡检（不要默认静默创建）：

- 环境若是 **Grok Bot / Codex**（或其它支持日程例程、定时任务的助手）：说明可以加一条 **routine**，定期跑 **Doctor**（健康检查），发现问题按 I2 **自动修复**（假活强制重启等），修好或修不了再通知。
- 建议默认节奏：每 **15–30 分钟** 或每小时一次 Doctor 轻检；Access OTP 过期类问题以「提醒重新登录」为主，不要假装能无交互续 OTP。
- 用户说要 → 进入 **J. Monitor**，按环境创建例程/定时任务；用户说不要 → 仍提醒本机可用 `templates/ensure-tunnel.sh` 做进程级保活，并告知以后说「doctor / 诊断一下」可再跑 I。

---

## F. 硬停条件

1. 用户没有域名且拒绝购买  
2. 探针干净网络下仍 `STOP_NO_CF_REACH`  
3. 用户明确拒绝成本  
4. 坚持只要 `trycloudflare` / 无 zone 主机名  

不要硬编无域名方案。

---

## G. 已知坑

| 坑 | 处理 |
|----|------|
| 开场写「能上网」含糊 | **禁止**；写「本机网络能摸到 Cloudflare（预检）」 |
| 在 skill/话术里提联盟返佣 | **禁止** |
| 未先退出 Clash 就预检 | 开场先要求退出；`RETRY_AFTER_QUIT_PROXY` 再退再测 |
| Clash TUN fake-ip `198.18.0.0/15` | 同上；翻墙机器侧 edge 解析成 fake-ip 会导致 `:7844` dial 超时 |
| Clash 未 DIRECT `cloudflared` | access tcp 失败/极慢 / `websocket: bad handshake` |
| Clash TUN 未排除 Cloudflare **IPv6**（仅排除了 104/172 等 IPv4） | `cloudflared` 经 utun 源地址 `fdfe:dcba:9876::1` 连 `2606:4700::` → `websocket: bad handshake`；IPv4 route-exclude 仍可能「DNS/路由看起来正常」。Merge `tun.route-exclude-address` 须含 `2606:4700::/32`（及常用 CF IPv6：`2803:f800::/32`、`2400:cb00::/32`、`2405:8100::/32`、`2405:b500::/32`、`2a06:98c0::/29`）。Doctor：`lsof -nP -p <pid>` 看出站是否走 TUN IPv6 |
| **隧道假活（zombie）** | 本机 `ha_connections≥1`，但 Cloudflare API `status=down` / `connections=[]`；Access 报 `websocket: bad handshake`。**只看本地指标会漏**；见 I |
| Access OTP / app token 过期 | 会话常约 24h；重新 `cloudflared access login` 或浏览器 OTP，再重启 access tcp |
| 临时邮箱收不到注册商 OTP | 优先个人邮箱；换渠道或改邮箱 |
| 默认信用卡结账文案 | **禁止**；支付宝/微信扫码、本人付 |
| 列多个域名让用户选 | **禁止**；只推一个名 |
| 引导续费原域名 | **禁止**；到期换新便宜域迁移 |
| OpenAI / Codex 被拦 | 已知限制 |
| 用 1.1.1.1 通不通当总开关 | **禁止** |

---

## H. 助手文件位置

相对本 skill 目录（`/home/box/agent-data/workflows/cloudflare-tunnel-proxy/`）或本仓库根：

| 路径 | 用途 |
|------|------|
| `scripts/preflight-cf-reach.sh` | 客户端网络预检 |
| `scripts/doctor.sh` | Doctor 轻检编排：分层跑完打印 `status=` + `RESULT` 行 |
| `scripts/doctor-*.sh` | 分层探针 RESULT：`access` / `cf` / `tunnel_ha` / `local_proxy` / `e2e` / `clash_ipv6` |
| `scripts/diagnose-repair.md` | Doctor：挂了时分层诊断与修复清单（给人看） |
| `templates/connect_proxy.py` | 翻墙机器 CONNECT 代理 |
| `templates/start.sh` / `ensure.sh` / `stop.sh` | 启停保活 |
| `templates/ensure-tunnel.sh` | 隧道保活样例（本地 ha + CF connectors 交叉验证假活；可配 `PIN_CMD`/`UP_CMD`） |
| `box-connect-proxy.md` | 翻墙机器部署短说明 |
| `AUTHOR_LINKS.md` | 支持支付宝/微信的注册商官网（无联盟内容） |

---

## I. Doctor · 诊断与修复（health / healthy / 挂了）

用户反馈节点不通 / `generate_204` 非 204 / Clash 选该节点失败，或主动说 **doctor / health / 诊断 / 还通不通** 时：按层排查，**先结论后动手**。不要一上来重装域名或新建账户。

### I0. 链路与典型症状

```
Clash / curl → 你的电脑 127.0.0.1:PORT（access tcp 监听）
  → cloudflared access（Access JWT）
  → https://proxy.<domain> WebSocket
  → Cloudflare edge → Named Tunnel
  → 翻墙机器 127.0.0.1:PORT（CONNECT 代理）
  → 出口
```

| 现象 | 优先怀疑 |
|------|----------|
| 你的电脑连 `127.0.0.1:PORT` reset / 无监听 | 你的电脑上 `access tcp` 没起来 |
| access 日志 `websocket: bad handshake` | **隧道假活**、Access 未放行/token 无效、Clash 套娃（含 **TUN IPv6** 未 exclude） |
| 翻墙机器本地 `ha≥1` 但面板/API 隧道 `down` | **假活**：进程连着旧 edge，控制面已不路由 |
| 出站 dial `198.18.x.x:7844` 超时 | 翻墙机器/你的电脑 DNS 被 fake-ip 污染 |
| 407 Proxy Authentication Required | CONNECT 鉴权错或没带 |
| Access 302 登录页 | OTP/会话过期 |

### I1. 分层检查（顺序固定）

**1) 翻墙机器 CONNECT 代理（`local_proxy`）**

- 进程在听 `127.0.0.1:<PORT>`（不是 `0.0.0.0`）
- 翻墙机器上带鉴权：`curl -x http://USER:PASS@127.0.0.1:PORT -o /dev/null -w '%{http_code}\n' https://www.google.com/generate_204` → **204**
- 失败 → 先修 `connect_proxy` / `ensure.sh`，别动隧道

**2) Named Tunnel（必须双看）**

- **本地：** cloudflared 进程在；metrics 里 `cloudflared_tunnel_ha_connections ≥ 1`
- **权威：** Cloudflare API 或面板：该 tunnel `status=healthy` 且 `connections` 非空
- **假活判定：** 本地 ha≥1 **且** API `status=down` / `connections=[]` → 视为断，进入 I2
- DNS：`proxy.<domain>` CNAME → `<TUNNEL_UUID>.cfargotunnel.com`（Proxied）；ingress 含 `tcp://127.0.0.1:<PORT>`
- 建议 `protocol: http2`；若 edge 曾被解析成 `198.18.0.0/15`，用 DoH 钉真实 edge IP 到 hosts（或等价销毒），避免 dial 假 IP

**3) Access**

- 应用保护 `proxy.<domain>`；策略 Allow 用户邮箱；OTP 可用
- 客户端：`cloudflared access token -app https://proxy.<domain>` 能出 JWT，且未过期
- 过期 → 浏览器/`access login` 重新 OTP，再重启 access tcp

**4) 你的电脑 access tcp + Clash**

- `cloudflared access tcp --hostname proxy.<domain> --url 127.0.0.1:<PORT>` 在听
- 日志无持续 `bad handshake`
- Clash：该节点指向本机 PORT + 正确 user/pass；**`cloudflared` 与 `proxy.<domain>` DIRECT**；Merge 里给 Access / 隧道域名 fake-ip-filter，并排除 CF IPv4+IPv6；`lsof` 确认未走 `fdfe:dcba`→`2606:4700`
- 端到端：`curl -x http://USER:PASS@127.0.0.1:PORT … generate_204` → **204**

### I2. 修复动作（对症）

| 判定 | 动作 |
|------|------|
| CONNECT 挂了 | `ensure.sh` / 重启 `connect_proxy`；确认只绑回环 + auth |
| **隧道假活** 或 API down | **杀掉**该 named tunnel 的 cloudflared 进程，让保活包装拉起；等 API 变 `healthy` 且 connections≥1；**不要**只 `ensure` 看本地 ha（假活时 ha 仍可能 ≥1） |
| edge / fake-ip | 重跑 edge pin（DoH→hosts）；确认未再解析到 `198.18.0.0/15` |
| Access token 过期 | 重新 OTP；更新 token 文件后重启 access tcp |
| access 仍 bad handshake 且隧道已 healthy | 查 Clash 是否劫持 cloudflared（**先看 `lsof` 是否 `fdfe:dcba`→`2606:4700`**）；补 IPv6 `route-exclude-address`；临时关 TUN 复测；确认 DIRECT 规则 |
| DNS/CNAME 错 | 修成指向正确 `<TUNNEL_UUID>.cfargotunnel.com` |

修复后必须以 **端到端 204** 为完成标准；只报「进程在」不算修好。

### I3. Doctor 轻检（给 Monitor / cron 用）

优先跑可执行轻检（避免每次手刷面板）：

```bash
HOSTNAME=proxy.<domain> \
TUNNEL_ID=<TUNNEL_UUID> \
ORIGIN_PORT=<PORT> \
AUTH_FILE=/path/to/proxy.auth \
CFG=$HOME/.cloudflared/<tunnel>.yml \
ROLE=host \
bash "<本 skill 目录>/scripts/doctor.sh"
# 在你的电脑上诊断时改 ROLE=client（跳过翻墙机器专属层，避免误报 status=down）
# ROLE 省略时行为与旧版相同（auto），跨机器误读仍可能出现
```

输出：`status=OK|degraded|down` 与各层 `RESULT <键>=OK|FAIL|SKIP`（键见上）；**仅 `status=OK` 时 exit 0**。对用户复述时用「你的电脑 / 翻墙机器」，不要说 Origin。

层顺序与 RESULT 键：`access` → `cf` → `tunnel_ha` → `local_proxy` → `e2e` → `clash_ipv6`（Access JWT 可选 → CF connectors / 假活交叉验证 → 翻墙机器本地 `ha_connections` → 翻墙机器 CONNECT `generate_204` → 你的电脑若有 access tcp 再 e2e → macOS Clash TUN IPv6）。

任一步失败 → 走 I2；需要人工 OTP 时**停止自动修**并通知用户。更细的命令清单见 `scripts/diagnose-repair.md`。

---

## J. Monitor · 保活与例程

目标：链路持续可用；假活能被发现并自动拉起；修不了的（尤其 Access OTP）及时喊人。

**优先顺序：常驻/cron 脚本 → 助手例程仅作兜底。** 不要用高频 Grok Bot routine 轮询代替 `ensure`/`doctor.sh`。

### J1. 翻墙机器 / 进程级保活（始终建议，Monitor 主路径）

- CONNECT：`templates/ensure.sh`（cron / systemd timer / 短循环）  
- 隧道：`templates/ensure-tunnel.sh`（设 `TUNNEL_ID`；可选 `PIN_CMD` / `UP_CMD`）——**不能**只信本地 `ha_connections`：  
  1. 本地 ha==0 → 重启 cloudflared  
  2. 本地 ha≥1 但 CF connectors=0 → **强制重启**（假活）；只杀该 `CFG` 对应进程  
  3. 可选：cron 再跑 `scripts/doctor.sh`；连续非 OK 再告警  
- **勿**误杀同一主机上其它隧道  
- Clash：安装/改 Merge 时固定写入 cloudflared DIRECT + 隧道/Access 域名 fake-ip-filter + Cloudflare **IPv4 与 IPv6** `tun.route-exclude-address`  

### J2. 助手例程（Grok Bot / Codex 等）——仅 OTP / 需人工时的 fallback

脚本能覆盖的保活与轻检（J1 + `doctor.sh`）**不要**再建密轮询例程。仅在下列情况加 routine：

1. Access OTP / token 过期需人点登录  
2. 你的电脑（Clash Merge、LaunchAgent）脚本够不着  
3. 用户明确要求助手盯着并通知  

若仍建例程：间隔 ≥15–30 分钟；正文跑 I3/`doctor.sh`；失败按 I2；需 OTP 则通知并停自动修；**健康时保持安静**。

### J3. 无例程 / 无助手环境

装上 J1 cron/systemd，并告诉用户手动说「doctor」或直接跑 `scripts/doctor.sh` 即可复检。

---

## 成功标准（清单）

- [ ] 已先退出本机代理后再预检；`RESULT=CONTINUE`  
- [ ] Cloudflare Free 可用；域名 zone Active  
- [ ] 域名经支付宝/微信渠道购买；单一短名  
- [ ] Named Tunnel 健康（**API/面板 healthy**，不只本地 ha）；`proxy.<domain>` → `tcp://127.0.0.1:<PORT>`  
- [ ] Access + 用户邮箱 OTP Allow  
- [ ] 翻墙机器代理仅 `127.0.0.1` + 随机 Basic auth  
- [ ] 你的电脑 `cloudflared access tcp` + OTP 成功  
- [ ] `curl … generate_204` → **204**  
- [ ] 已告知 OpenAI 可能不可用  
- [ ] Setup 后已询问是否加 Monitor 例程（Grok Bot / Codex 等）  
- [ ] 保活含「假活」检测（本地 ha 与 Cloudflare 状态交叉验证）  

完成后把主机名、端口、鉴权交给用户私密保存；正文不写真实密钥。
