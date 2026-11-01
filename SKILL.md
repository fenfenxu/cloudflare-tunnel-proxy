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

链路（记熟，排障按此分层；**Access OTP 是进隧道前的认证，不是链路上的一跳**）：

```
你的电脑（Clash / cloudflared access tcp）
  → Cloudflare 命名隧道
  → 翻墙机器上 127.0.0.1 CONNECT 代理
  → 翻墙机器出口访问外网

旁注：进入隧道前需 Cloudflare Access 邮箱 OTP（认证门禁，不是网络跳点）
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


## 安全方案说明（助手必守）

对人解释与动手时，把安全当成产品能力，不要当「可选加固」：

| 层 | 要求 | 助手动作 |
|----|------|----------|
| Access OTP | 用用户**个人邮箱** Allow + One-time PIN；会话常约 **24h**，过期要用户重新 OTP | 过期只引导重新登录；**不要**假装能无交互续 OTP；不要把「要重新验证」说成翻墙机器挂了 |
| 只绑回环 | 翻墙机器 CONNECT **仅** `127.0.0.1:<PORT>` | 启动后确认监听地址；发现 `0.0.0.0` → 立刻停掉并改回环 |
| CONNECT Basic auth | 必须有随机强密码的 `proxy.auth` | 用 `openssl rand` 生成；**禁止**无密码/弱密码/文档示例串 |
| 不暴露公网端口 | 不开放防火墙/安全组；不用 trycloudflare 当生产入口 | 见 F / Setup 硬禁止 |
| 密钥存放 | `proxy.auth`、隧道凭证等 **chmod 600**；聊天/记忆/skill **永不写真实密码或生产主机名** | 对用户口述或让其本地保存；文档只用 `USER`/`PASS`/`proxy.<domain>` 占位符 |
| 破坏性操作 | 删隧道、弃用旧域、杀非本隧道进程、改生产配置 | **先说明后果，等用户明确确认**再执行 |
| 域名付款 | 支付宝/微信扫码 | **仅用户本人付**；助手不代付、不提联盟/返佣 |

链路本身的安全叙事（可原话告诉用户）：陌生人过不了 Access OTP；过了隧道也只能打到翻墙机器的回环代理；回环上还有 Basic auth。三层缺一不可。

## A. Setup · 开场（先发整体方案图，再短清单；禁止长文堆砌）

对用户做 Setup 时，**第一屏必须先发整体方案图**（ASCII 或 mermaid 均可），再接「要具备什么」与「接下来几步」。不要把架构埋到 README 深处才说。聊天里**不要**贴大段成本说明。措辞要直白，**禁止**用含糊的「能上网」。

**整体方案（先给人看这张图）**

```
你的电脑（Clash / cloudflared access tcp）
  → Cloudflare 命名隧道
  → 翻墙机器 CONNECT 代理（只绑 127.0.0.1）
  → 翻墙机器出口访问外网

旁注：进入隧道前需 Access 邮箱 OTP（认证门禁，不是链路一跳）
```

```mermaid
flowchart LR
  C[你的电脑] --> T[Cloudflare 命名隧道]
  T --> P[翻墙机器 CONNECT]
  P --> O[出口]
```

> Access 邮箱 OTP = 进隧道前的身份验证，**不要**画成「你的电脑 → Access OTP → 隧道」那种网络跳点。

**要具备**
1. **本机网络能摸到 Cloudflare**（先完全退出 Clash / Verge / 其它 TUN，并关掉系统 HTTP/HTTPS/SOCKS 代理，再跑预检；通了才继续）
2. **一个 Cloudflare 账户**（没有可用邮箱**免费注册**；OTP 优先常用**个人邮箱**；临时邮箱常收不到注册商验证码）
3. **一个自己的完整域名**（没有也可现买；助手选便宜档，首年常约 **$1** 量级；付费用**支付宝或微信**扫码，用户本人付）
4. 接受：出口常是 CF / 机房 IP，**OpenAI / Codex 等可能不可用**（已知限制）

**接下来做什么（安装向导）**
1. 预检：本机能否访问 Cloudflare  
2. 注册/登录 Cloudflare（免费）  
3. 助手选一个便宜域名 → 你支付宝/微信付款 → NS 指到 CF  
4. 翻墙机器起本地代理 → 开隧道 + Access 门禁 → 你的电脑装 `cloudflared` 验证  

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

### E8. Setup 完成后：写 site.env（配置清单，不含密码）+ 询问 Monitor

端到端 **204** 之后，助手**必须**在翻墙机器部署目录旁写入 `site.env`（也可叫 `inventory.env`；模板见 `templates/site.env.example`），供 Doctor / ensure / Monitor **读取**，不要把 HOSTNAME、TUNNEL_ID、端口等硬编码进脚本。

- **翻墙机器（必写）：** 与 `proxy.auth` 同级，例如部署目录下的 `site.env`
- **你的电脑（可选副本）：** 只放客户端 Doctor 需要的键（如 `HOSTNAME`、`ROLE=client`、`ORIGIN_PORT` / `LISTEN_PORT`、`CFD`）
- **允许键：** `HOSTNAME`、`TUNNEL_ID`、`TUNNEL_NAME`、`ORIGIN_PORT` / `LISTEN_PORT`、`CFG`、`AUTH_FILE`（路径）、`ROLE`、`CFD`、`ACCESS_APP_URL`、`NOTES` 等
- **禁止写入：** 密码、tunnel token、Access JWT、`proxy.auth` 内容
- Doctor 自动加载：`SITE_ENV`，或 `./site.env` / `./inventory.env`，或 `$AUTH_FILE` 同目录的 `site.env`（见 `scripts/load-site-env.sh`）；已在环境里显式设置的变量不被覆盖

然后**必须**用一两句话问用户要不要加保活/巡检（不要默认静默创建）：

- 环境若是 **Grok Bot / Codex**（或其它支持日程例程、定时任务的助手）：说明可以加一条 **routine**，定期跑 **Doctor**（健康检查），发现问题按 I2 **自动修复**（假活强制重启等），修好或修不了再通知。
- 建议默认节奏：每 **15–30 分钟** 或每小时一次 Doctor 轻检；Access OTP 过期类问题以「提醒重新登录」为主，不要假装能无交互续 OTP。
- 用户说要 → 进入 **J. Monitor**，按环境创建例程/定时任务；用户说不要 → 仍提醒本机可用 `templates/ensure-tunnel.sh` 做进程级保活，并告知以后说「doctor / 诊断一下」可再跑 I。

---


## F. 硬停条件与 Setup 硬禁止

### F1. 硬停（直接停，不要硬编替代方案）

1. 用户没有域名且拒绝购买  
2. 探针干净网络下仍 `STOP_NO_CF_REACH`  
3. 用户明确拒绝成本  
4. 坚持只要 `trycloudflare` / 无 zone 主机名  

### F2. Setup 硬禁止清单（与 G 对齐；违者当场纠正）

助手在 Setup **全程自检**，下列任一出现 → 停下改正，不要带着错误继续：

- [ ] **禁止**无密码、弱密码、或使用文档/模板里的示例密码；必须 `openssl rand`（或同等）生成随机串  
- [ ] **禁止** CONNECT / 本地代理监听 `0.0.0.0` 或其它非回环地址；只允许 `127.0.0.1`  
- [ ] **禁止** trycloudflare-only / 无自有域名方案；无 zone = NO-GO  
- [ ] **禁止**把 `proxy.auth`、真实密码、生产主机名、隧道凭证写进 skill、README、聊天记录或记忆；只给用户私密保存
- [ ] **禁止**把密码 / token / JWT / `proxy.auth` 内容写进 `site.env` / `inventory.env`（清单只含非密钥配置）  
- [ ] **禁止**提及联盟、返佣、referral、带货佣金；域名链接只用 `AUTHOR_LINKS.md` 官网  
- [ ] **禁止**未完全退出 Clash / Verge / 系统 HTTP(S)/SOCKS 代理就跑预检  
- [ ] **禁止**引导续费原便宜域名；到期策略 = 买新域迁移后弃用旧域  
- [ ] **禁止**用「1.1.1.1 通不通」或含糊「能上网」代替 Cloudflare 预检结论  
- [ ] **禁止**一次列出多个域名让用户挑；只生成并推进 **一个** 短名  
- [ ] **禁止**助手代付；禁止默认「信用卡结账」话术——支付宝/微信、用户本人付  
- [ ] **禁止**未获用户确认就做删隧道、弃用旧域、误杀其它隧道等破坏性操作  
- [ ] **禁止**把隧道凭证文件权限放宽到他人可读；目标 `600`

与 **G. 已知坑** 同一套红线；G 偏排障，F2 偏 Setup 闸门。

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
| `templates/ensure-tunnel.sh` | 隧道保活样例（本地 ha + CF connectors 交叉验证假活；可配 `PIN_CMD`/`UP_CMD`；可读 site.env） |
| `templates/site.env.example` | Setup 后站点配置清单模板（无密码；翻墙机器必写，你的电脑可选副本） |
| `scripts/load-site-env.sh` | Doctor/ensure 加载 `SITE_ENV` / `site.env` / `inventory.env` |
| `box-connect-proxy.md` | 翻墙机器部署短说明 |
| `AUTHOR_LINKS.md` | 支持支付宝/微信的注册商官网（无联盟内容） |

---

## I. Doctor · 诊断与修复（health / healthy / 挂了）

用户反馈节点不通 / `generate_204` 非 204 / Clash 选该节点失败，或主动说 **doctor / health / 诊断 / 还通不通** 时：按层排查，**先结论后动手**。不要一上来重装域名或新建账户。

### I0. 链路与典型症状

```
Clash / curl → 你的电脑 127.0.0.1:PORT（access tcp 监听）
  → Cloudflare 命名隧道（WebSocket 至 edge；进入前需 Access 邮箱 OTP / JWT 认证，不是单独一跳）
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
# 若部署目录已有 site.env，可直接：
#   cd /path/to/deploy && bash "<本 skill 目录>/scripts/doctor.sh"
# 或：SITE_ENV=/path/to/site.env bash .../doctor.sh
# 仍可用环境变量显式覆盖清单中的值：
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


## FAQ（对用户可直接复述；助手先查这里）

1. **Access 授权/会话有期限吗？**  
   有。常见大约 **24 小时**。过期后在**你的电脑**重新邮箱 OTP（`cloudflared access login` 或浏览器），再重启 `access tcp`。不要判成翻墙机器故障。

2. **OpenAI / Codex 不通算失败吗？**  
   不算。出口 CF/机房 IP 的已知限制。成功标准仍是带鉴权 `generate_204` → **HTTP 204**。

3. **Doctor 在哪台机器跑？**  
   分角色：翻墙机器查 `local_proxy` / 隧道；你的电脑查 Access / access tcp / Clash。设 `ROLE=host` 或 `ROLE=client`（见 I3）。角色读错会出现假 FAIL。

4. **什么是隧道假活（zombie）？**  
   本地 `ha_connections≥1`，但 Cloudflare API/面板 `status=down` 或 `connections=[]`。只看本地会漏。处理：杀掉该 named tunnel 的 cloudflared，让保活拉起，等 API healthy（见 I2 / `ensure-tunnel.sh`）。

5. **为什么预检前必须退出 Clash？**  
   TUN / fake-ip（`198.18.0.0/15`）会污染 DNS 与探测，导致 `RETRY_AFTER_QUIT_PROXY` 或误报 `STOP_NO_CF_REACH`。

6. **Clash 已 DIRECT 仍 bad handshake？**  
   常是 **IPv6 TUN 套娃**：未把 `2606:4700::/32` 等 CF IPv6 写入 `tun.route-exclude-address`。用 `lsof` 看出站是否 `fdfe:dcba…` → `2606:4700`（见 G / `doctor-clash-ipv6.sh`）。

7. **为什么不能只用 trycloudflare？**  
   本产品硬前提是自有域名 zone + Access 主机名。无域名 / trycloudflare-only → **硬停**（F1）。

8. **密码能否写进聊天让助手记住？**  
   **不能。** 随机生成后只放翻墙机器 `proxy.auth`（`600`）和用户自己的密码管理器；skill/记忆/聊天用占位符。

9. **域名到期要续费吗？**  
   **禁止**引导续费原便宜域。到期前买新域、迁移 `proxy.<新域>` / DNS / Access / 客户端，204 后再弃用旧域；付款用户本人。

10. **Monitor 能自动续 Access OTP 吗？**  
    不能。脚本保活只管进程/假活；OTP 过期只能通知用户手动重新登录（见 J2）。

11. **site.env / 配置清单里有密码吗？**  
    **没有。** 只记主机名、隧道 ID、端口、配置路径等非密钥项；密码仍只在 `proxy.auth`（见 E8）。

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
- [ ] Setup 开场已先展示整体方案图（隧道链路；Access OTP 仅作认证旁注）再给短清单  
- [ ] Setup 后已写入翻墙机器 `site.env`（无密码）；Doctor 可从中加载  
- [ ] Setup 后已询问是否加 Monitor 例程（Grok Bot / Codex 等）  
- [ ] 保活含「假活」检测（本地 ha 与 Cloudflare 状态交叉验证）
- [ ] Setup 未触犯 F2 硬禁止（回环、随机密码、无联盟、未把 proxy.auth / 密码写入 skill/聊天/site.env）  
- [ ] 已向用户说明 Access 会话约 24h 需重新 OTP  
  

完成后把主机名、端口、鉴权交给用户私密保存；正文不写真实密钥。
