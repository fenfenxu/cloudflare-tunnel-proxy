---
name: Cloudflare Tunnel Proxy
description: >-
  When the user wants to set up, diagnose (doctor/health), or monitor a personal Cloudflare Tunnel + Access TCP proxy—including colloquial asks about 翻墙, 梯子, 代理, 隧道, CF, Cloudflare, Cloudflare梯子, Cloudflare翻墙代理, or a broken Clash CF node: route to Setup (A–H + offer keepalive routine), Doctor (I), or Monitor (J). Not for trycloudflare-only or domain-less paths. Do not mention affiliate/referral.
---

# Cloudflare Tunnel Proxy

用 **免费 Cloudflare 账户 + 已接入 Cloudflare 的域名 + 一台可常驻的 origin 主机**，做一条个人代理：

```
客户端 cloudflared access tcp
  → Cloudflare Access（邮箱 OTP）
  → Named Tunnel
  → origin 上 127.0.0.1 CONNECT 代理
  → 隧道所在出口
```

**硬前提：** 必须有 Cloudflare 上的 zone（域名）。`*.trycloudflare.com` / 无域名 / 无 Access TCP 主机名 = **NO-GO**。

助手专属细节（某人的邮箱、生产主机名、现成密码）**不要**写进本 skill；一律用占位符。把用户当普通新用户：不要假设已有 CF/域名/`cloudflared`/现成隧道。

**禁止**在本 skill、开场说明或对用户话术里提及联盟、返佣、referral、带货佣金；买域名只谈用户怎么付、付多少。

本 skill 是**一组能力**（一个入口、多种模式），先路由再动手：

| 模式 | 用户说法（例） | 去做 |
|------|----------------|------|
| **Setup** | 搭梯子 / 翻墙 / 装代理 / Cloudflare 隧道 / 从零 setup | A–H，装完再问是否挂 Monitor 例程 |
| **Doctor** | 挂了 / 不通 / 诊断 / doctor / health / healthy / 还通不通 | I，分层诊断与修复；不要从头重装 |
| **Monitor** | 保活 / 监控 / monitor / 定时检查 / 自动修 | J，例程或保活脚本；可选端到端探测 |

不确定时：已有链路且在抱怨不通 → **Doctor**；否则 → **Setup**。

---

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
4. origin 起本地代理 → 开隧道 + Access → 本机装 `cloudflared` 验证  

一句问是否继续。不愿买域名或拒绝成本 → **硬停**（见 F）。

---

## B. Setup · 预检网络（先退出代理，再跑探针）

开场已要求退出代理后，在用户 **Mac 或 Linux** 跑：

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

### E3. origin：本地 CONNECT 代理（只绑回环）

在隧道所在 **origin 主机**上部署（详见 `box-connect-proxy.md` 与 `templates/`）：

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

### E6. 客户端：cloudflared access tcp（+ 可选 Clash）

假定本机**尚未**安装 `cloudflared`（冷启动按新装验证；若已有则先卸再装亦可按用户环境）。

```bash
brew install cloudflare/cloudflare/cloudflared
# 或官方下载页

cloudflared access tcp --hostname proxy.<domain> --url 127.0.0.1:<PORT>
```

可选 Clash HTTP 节点：`127.0.0.1:<PORT>` + `proxy.auth`。**Clash 必须给 `cloudflared` 走 DIRECT**（域名 `proxy.<domain>`、`*.cloudflareaccess.com`、进程名均直连），否则 Access WebSocket 会套娃或握手失败。

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
| Clash TUN fake-ip `198.18.0.0/15` | 同上；origin 侧 edge 解析成 fake-ip 会导致 `:7844` dial 超时 |
| Clash 未 DIRECT `cloudflared` | access tcp 失败/极慢 / `websocket: bad handshake` |
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
| `scripts/diagnose-repair.md` | Doctor：挂了时分层诊断与修复清单（给人看） |
| `templates/connect_proxy.py` | origin CONNECT 代理 |
| `templates/start.sh` / `ensure.sh` / `stop.sh` | 启停保活 |
| `templates/ensure-tunnel.sh` | 隧道保活样例（须对照 Cloudflare 状态，不能只看本地 ha） |
| `box-connect-proxy.md` | origin 部署短说明 |
| `AUTHOR_LINKS.md` | 支持支付宝/微信的注册商官网（无联盟内容） |

---

## I. Doctor · 诊断与修复（health / healthy / 挂了）

用户反馈节点不通 / `generate_204` 非 204 / Clash 选该节点失败，或主动说 **doctor / health / 诊断 / 还通不通** 时：按层排查，**先结论后动手**。不要一上来重装域名或新建账户。

### I0. 链路与典型症状

```
Clash / curl → 本机 127.0.0.1:PORT（access tcp 监听）
  → cloudflared access（Access JWT）
  → https://proxy.<domain> WebSocket
  → Cloudflare edge → Named Tunnel
  → origin 127.0.0.1:PORT（CONNECT 代理）
  → 出口
```

| 现象 | 优先怀疑 |
|------|----------|
| 本机连 `127.0.0.1:PORT` reset / 无监听 | 客户端 `access tcp` 没起来 |
| access 日志 `websocket: bad handshake` | **隧道假活**、Access 未放行/token 无效、Clash 套娃 |
| origin 本地 `ha≥1` 但面板/API 隧道 `down` | **假活**：进程连着旧 edge，控制面已不路由 |
| 出站 dial `198.18.x.x:7844` 超时 | origin/本机 DNS 被 fake-ip 污染 |
| 407 Proxy Authentication Required | CONNECT 鉴权错或没带 |
| Access 302 登录页 | OTP/会话过期 |

### I1. 分层检查（顺序固定）

**1) origin CONNECT 代理**

- 进程在听 `127.0.0.1:<PORT>`（不是 `0.0.0.0`）
- origin 上带鉴权：`curl -x http://USER:PASS@127.0.0.1:PORT -o /dev/null -w '%{http_code}\n' https://www.google.com/generate_204` → **204**
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

**4) 客户端 access tcp + Clash**

- `cloudflared access tcp --hostname proxy.<domain> --url 127.0.0.1:<PORT>` 在听
- 日志无持续 `bad handshake`
- Clash：该节点指向本机 PORT + 正确 user/pass；**`cloudflared` 与 `proxy.<domain>` DIRECT**；Merge 里给 Access / 隧道域名 fake-ip-filter
- 端到端：`curl -x http://USER:PASS@127.0.0.1:PORT … generate_204` → **204**

### I2. 修复动作（对症）

| 判定 | 动作 |
|------|------|
| CONNECT 挂了 | `ensure.sh` / 重启 `connect_proxy`；确认只绑回环 + auth |
| **隧道假活** 或 API down | **杀掉**该 named tunnel 的 cloudflared 进程，让保活包装拉起；等 API 变 `healthy` 且 connections≥1；**不要**只 `ensure` 看本地 ha（假活时 ha 仍可能 ≥1） |
| edge / fake-ip | 重跑 edge pin（DoH→hosts）；确认未再解析到 `198.18.0.0/15` |
| Access token 过期 | 重新 OTP；更新 token 文件后重启 access tcp |
| access 仍 bad handshake 且隧道已 healthy | 查 Clash 是否劫持 cloudflared；临时关 TUN 复测；确认 DIRECT 规则 |
| DNS/CNAME 错 | 修成指向正确 `<TUNNEL_UUID>.cfargotunnel.com` |

修复后必须以 **端到端 204** 为完成标准；只报「进程在」不算修好。

### I3. Doctor 轻检（给 Monitor / routine 用）

定时巡检可只做「轻检」，避免每次刷面板：

1. origin：CONNECT `generate_204` → 204  
2. 隧道：本地 ha≥1 **且** API/面板 healthy（交叉验证，防假活）  
3. 可选客户端：本机经 access 端口再打一次 `generate_204`  
4. 任一步失败 → 走 I2；需要人工 OTP 时**停止自动修**并通知用户  

更细的检查命令清单见 `scripts/diagnose-repair.md`。

---

## J. Monitor · 保活与例程

目标：链路持续可用；假活能被发现并自动拉起；修不了的（尤其 Access OTP）及时喊人。

### J1. origin / 进程级保活（始终建议）

- CONNECT：`templates/ensure.sh`（或等价 cron/systemd）  
- 隧道：`templates/ensure-tunnel.sh`——**不能**只信本地 `ha_connections`：  
  1. 本地 ha==0 → 重启 cloudflared  
  2. 本地 ha≥1 但 API down → **强制重启**（假活）  
  3. 可选：端到端 `generate_204` 连续失败再告警  
- **勿**误杀同一主机上其它隧道  
- Clash：安装/改 Merge 时固定写入 cloudflared DIRECT + 隧道/Access 域名 fake-ip-filter  

### J2. 助手例程（Grok Bot / Codex 等）

Setup 完成后用户同意，或用户主动要 Monitor 时：

1. 创建定时例程（名称示例：`Cloudflare Tunnel Proxy · doctor`）  
2. 触发：每 15–30 分钟或每小时（按用户偏好；不要密于 5 分钟）  
3. 例程正文要点（占位符替换成该用户的主机名/路径，**不要**把密钥写进例程明文若可避免）：  
   - 加载本 skill，走 **Doctor 轻检（I3）**  
   - 失败则按 I2 自动修复  
   - 需要 OTP / 用户本机操作 → 通知用户，不要空转  
   - **无变化且健康时保持安静**（不要每次都汇报「还好」）  
4. Access 会话约 24h：到期前可提醒续 OTP，或接受偶发重新登录；可在 Zero Trust 适当加长 session（权衡安全）

### J3. 无例程环境

若当前助手不能建 routine：把 J1 脚本装上，并告诉用户手动说「doctor」即可复检。

---

## 成功标准（清单）

- [ ] 已先退出本机代理后再预检；`RESULT=CONTINUE`  
- [ ] Cloudflare Free 可用；域名 zone Active  
- [ ] 域名经支付宝/微信渠道购买；单一短名  
- [ ] Named Tunnel 健康（**API/面板 healthy**，不只本地 ha）；`proxy.<domain>` → `tcp://127.0.0.1:<PORT>`  
- [ ] Access + 用户邮箱 OTP Allow  
- [ ] origin 代理仅 `127.0.0.1` + 随机 Basic auth  
- [ ] 客户端 `cloudflared access tcp` + OTP 成功  
- [ ] `curl … generate_204` → **204**  
- [ ] 已告知 OpenAI 可能不可用  
- [ ] Setup 后已询问是否加 Monitor 例程（Grok Bot / Codex 等）  
- [ ] 保活含「假活」检测（本地 ha 与 Cloudflare 状态交叉验证）  

完成后把主机名、端口、鉴权交给用户私密保存；正文不写真实密钥。
