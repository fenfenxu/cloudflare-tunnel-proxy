# 翻墙机器：部署 CONNECT 代理（模板）

**默认用 gost**（少依赖、更稳）；装不上 gost 或用户强制时，才用仓库里的 Python `connect_proxy.py` 兜底。客户端 Clash / Access / 命名隧道不变。

从本 skill 的 `templates/` 拷到**翻墙机器**工作目录（示例 `/workspace/network/cf-box-proxy/`）：

```bash
DEST=/workspace/network/cf-box-proxy
mkdir -p "$DEST"
cp templates/start.sh templates/ensure.sh templates/stop.sh \
   templates/install-gost.sh templates/connect_proxy.py "$DEST/"
chmod +x "$DEST"/{start.sh,ensure.sh,stop.sh,install-gost.sh,connect_proxy.py}
cd "$DEST"

# 必装 gost（官方二进制 / go install）；校验：gost -V
./install-gost.sh
export PATH="$HOME/.local/bin:$PATH"
command -v gost && gost -V
# 仅当上一行失败：export PROXY_BACKEND=python

# 随机 Basic auth（必做；不要用文档示例密码）
umask 077
USER=proxy
PASS="$(openssl rand -base64 18 | tr -d '/+=' | head -c 20)"
printf '%s:%s\n' "$USER" "$PASS" > proxy.auth
chmod 600 proxy.auth

./start.sh
# 或保活：./ensure.sh
# 等价手动：gost -L=http://USER:PASS@127.0.0.1:17897
```

`start.sh` 逻辑：`PROXY_BACKEND=auto`（默认）→ PATH 有 `gost` 就跑 gost，否则 Python；`gost` / `python` 可强制。

约束：

- 只绑 `127.0.0.1`（或 `::1`）；脚本会拒绝非回环。
- Cloudflare Tunnel ingress：`hostname: cf-tunnel-proxy.<domain>` → `service: tcp://127.0.0.1:17897`（端口可改，与 `PROXY_PORT` 一致）。
- 公网侧必须再套 Cloudflare Access（邮箱 OTP）；本地 Basic 是第二层。
- 隧道保活与 edge DNS 钉扎是环境相关运维；不要误杀翻墙机器上其它 `cloudflared` token 隧道。

验证（在翻墙机器本机）：

```bash
AUTH=$(tr -d '\n' < proxy.auth)
curl -o /dev/null -w '%{http_code}\n' -x "http://${AUTH}@127.0.0.1:17897" https://www.google.com/generate_204
```

期望 `204`。你的电脑仍需 `cloudflared access tcp` 才能从公网进来。

## 配置清单 site.env（不含密码）

Setup 成功后在本目录写 `site.env`（可参考仓库 `templates/site.env.example`）：主机名、隧道 ID、端口、`CFG` / `AUTH_FILE` 路径等。可选 `PROXY_BACKEND=gost`。**不要**写入密码或 token。Doctor / `ensure-tunnel.sh` 会自动加载。
