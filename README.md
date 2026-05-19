# 小米 AX9000 — mihomo (Clash.Meta) 透明代理 Docker 部署教程

> 🐣 **小白友好** — 一步一步，完全可複製貼上
> 📡 **透明代理** — 所有設備免設置自動走代理（包括未設定代理的 APP）
> 🔒 **運行在 Docker** — 不動原廠系統，韌體更新不受影響

---

## 📋 目錄

1. [前置需求](#前置需求)
2. [第一步：開啟 SSH](#第一步開啟-ssh)
3. [第二步：安裝 Docker](#第二步安裝-docker)
4. [第三步：部署 mihomo 容器](#第三步部署-mihomo-容器)
5. [第四步：配置透明代理](#第四步配置透明代理)
6. [第五步：開機自動啟動](#第五步開機自動啟動)
7. [第六步：廣告攔截](#第六步廣告攔截)
8. [第七步：廣告攔截規則](#第七步廣告攔截規則)
9. [節點配置說明](#節點配置說明)
10. [常見問題](#常見問題)

---

## 前置需求

- 小米 AX9000 路由器（已刷原廠固件）
- 電腦與 AX9000 在同一網絡（有线连接或同一 WiFi）
- 上級路由器（如有）已正確設置靜態路由（可選，見 [附錄 A](#附錄-a)）
- 節點訂閱或節點信息（VMess / VLESS / Trojan / Shadowsocks）

---

## 第一步：開啟 SSH

### 1.1 確認 SSH 狀態

在手機或電腦的終端執行：

```bash
ssh root@192.168.31.1
```

- **密碼**：`你的SSH密碼`（預設是 WiFi 密碼）
- 如果連不上，看 [附錄 A：跨網段 SSH 問題](#附錄-a)

### 1.2 開啟 SSH（如未開啟）

在路由器 Web 後台（`192.168.31.1`）:
`設置 → 硬件規格 → 開發者模式 → 開啟`

---

## 第二步：安裝 Docker

SSH 登入 AX9000 後，依次執行：

```bash
# 建立 Docker 目錄
mkdir -p /mnt/docker_disk/mi_docker/docker-binaries

# 下載 Docker CLI（本路由器架構 aarch64）
cd /mnt/docker_disk/mi_docker/docker-binaries

curl -fsSL "https://download.docker.com/linux/static/stable/aarch64/docker-26.1.0.tgz" | tar xz

# 賦權
chmod +x docker/*
```

**⚠️ 注意：** AX9000 是 `aarch64` 架構，不要下載 x86 版本。

---

## 第三步：部署 mihomo 容器

### 3.1 寫入配置文件

在 Mac/Linux 終端（不是 AX9000）新建配置文件：

```bash
nano ~/mihomo_config.yaml
```

**完整配置如下（請替換 `YOUR_UUID_HERE` 等內容）：**

```yaml
# ===== 基礎設置 =====
port: 12346          # HTTP 代理端口（mihomo 管理界面用這個）
socks-port: 12347    # SOCKS5 代理端口
mixed-port: 0        # 混合代理端口（0 = 關閉）
redir-port: 12348    # 透明代理端口（最重要！）
allow-lan: true      # 允許區域網設備連入
mode: rule           # 規則模式（推薦）
log-level: info      # 日誌級別
external-controller: 0.0.0.0:9090   # RESTful API 控制端口

# ===== DNS 設置（虛假 IP 模式） =====
dns:
  enable: true
  enhanced-mode: fake-ip   # 核心！返回假 IP 引導流量走代理
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 8.8.8.8
    - 8.8.4.4
  fallback:
    - 1.1.1.1
    - 1.0.0.1

# ===== 節點列表（請填入真實節點信息） =====
proxies:
  # ===== VMess 節點示例 =====
  - name: 日本節點-示例
    type: vmess
    server: jpexample.com
    port: 443
    uuid: YOUR_VMESS_UUID_HERE
    alterId: 0
    cipher: auto
    network: ws
    tls: true
    ws-opts:
      path: "/"
      headers:
        Host: jpexample.com

  # ===== VLESS 節點示例 =====
  - name: 香港節點-VLESS-示例
    type: vless
    server: hkexample.com
    port: 443
    uuid: YOUR_VLESS_UUID_HERE
    network: ws
    tls: true
    sni: hkexample.com
    ws-opts:
      path: "/"
      headers:
        Host: hkexample.com

  # ===== Trojan 節點示例 =====
  - name: 美國節點-Trojan-示例
    type: trojan
    server: usexample.com
    port: 443
    password: YOUR_TROJAN_PASSWORD_HERE
    sni: usexample.com

# ===== 代理組（訂閱通常自動生成） =====
proxy-groups:
  - name: auto
    type: select           # 手動選擇節點
    proxies:
      - 日本節點-示例
      - 香港節點-VLESS-示例
      - 美國節點-Trojan-示例

# ===== 分流規則 =====
rules:
  # AI 服務（ChatGPT / Claude / Gemini 等）
  - DOMAIN-SUFFIX,chatgpt.com,auto
  - DOMAIN-SUFFIX,openai.com,auto
  - DOMAIN-SUFFIX,api.openai.com,auto
  - DOMAIN-SUFFIX,claude.ai,auto
  - DOMAIN-SUFFIX,platform.claude.ai,auto
  - DOMAIN-SUFFIX,anthropic.com,auto
  - DOMAIN-SUFFIX,api.anthropic.com,auto
  - DOMAIN-SUFFIX,aistudio.google.com,auto
  - DOMAIN-SUFFIX,ai.google.dev,auto
  - DOMAIN-SUFFIX,gemini.google.com,auto
  - DOMAIN-SUFFIX,deepseek.com,auto
  - DOMAIN-SUFFIX,perplexity.ai,auto
  # 搜索引擎 / 影片
  - DOMAIN-SUFFIX,google.com,auto
  - DOMAIN-SUFFIX,youtube.com,auto
  - DOMAIN-SUFFIX,ytimg.com,auto
  # 社交媒體
  - DOMAIN-SUFFIX,x.com,auto
  - DOMAIN-SUFFIX,twitter.com,auto
  - DOMAIN-SUFFIX,threads.net,auto
  - DOMAIN-SUFFIX,threads.com,auto
  # 關鍵字匹配
  - DOMAIN-KEYWORD,chatgpt,auto
  - DOMAIN-KEYWORD,claude,auto
  - DOMAIN-KEYWORD,openai,auto
  - DOMAIN-KEYWORD,anthropic,auto
  - DOMAIN-KEYWORD,gemini,auto
  # 默認：其餘流量直連（改成 auto就走代理）
  - MATCH,DIRECT
```

### 3.2 上傳配置到 AX9000

```bash
scp ~/mihomo_config.yaml root@192.168.31.1:/mnt/docker_disk/mi_docker/mihomo_config.yaml
```

### 3.3 拉取並啟動 mihomo 容器

SSH 登入 AX9000，執行：

```bash
# 拉取 mihomo 鏡像（Clash.Meta 分支）
/mnt/docker_disk/mi_docker/docker-binaries/docker pull metacubex/mihomo:latest

# 啟動容器（後台運行）
/mnt/docker_disk/mi_docker/docker-binaries/docker run -d \
  --name mihomo \
  --restart unless-stopped \
  -v /mnt/docker_disk/mi_docker/mihomo_config.yaml:/config.yaml \
  -p 12346:12346 \
  -p 12347:12347 \
  -p 12348:12348 \
  -p 9090:9090 \
  metacubex/mihomo:latest
```

### 3.4 確認容器運行

```bash
/mnt/docker_disk/mi_docker/docker-binaries/docker ps
```

應該看到 `mihomo` 容器 Status 為 `Up`。

---

## 第四步：配置透明代理

> **原理：** 將路由器收到的外網流量 redirect 到 mihomo 的 `redir-port: 12348`，mihomo 根據規則分流，走代理或直連。

### 4.1 添加 iptables 規則

SSH 登入 AX9000，執行：

```bash
# 透明代理轉發（把所有區域網流量導向 mihomo）
iptables -t nat -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING 1 -p tcp --dport 443 -j REDIRECT --to-ports 12348

# 允許本機訪問
iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I INPUT -s 192.168.0.0/16 -j ACCEPT

# DNS 劫持（讓 DNS 請求也走代理）
iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j REDIRECT --to-ports 12348
```

### 4.2 測試代理是否正常

在 Mac 瀏覽器打開 `https://chatgpt.com`，觀察是否正常訪問。

或在終端測試：

```bash
curl -x http://192.168.31.1:12346 https://api.openai.com/v1/models
```

---

## 第五步：開機自動啟動

> AX9000 重啟後 Docker / mihomo / iptables 規則會消失，需要腳本自動恢復。

### 5.1 寫入開機腳本

SSH 登入 AX9000，執行：

```bash
cat > /etc/rc.local << 'EOF'
#!/bin/sh

# ===== 等待網絡就緒 =====
sleep 10

# ===== 啟動 Docker =====
/mnt/docker_disk/mi_docker/docker-binaries/dockerd > /dev/null 2>&1 &
sleep 5

# ===== 啟動 mihomo 容器 =====
cd /mnt/docker_disk/mi_docker
/mnt/docker_disk/mi_docker/docker-binaries/docker start mihomo 2>/dev/null || \
  /mnt/docker_disk/mi_docker/docker-binaries/docker run -d \
    --name mihomo \
    --restart unless-stopped \
    -v /mnt/docker_disk/mi_docker/mihomo_config.yaml:/config.yaml \
    -p 12346:12346 -p 12347:12347 -p 12348:12348 -p 9090:9090 \
    metacubex/mihomo:latest

# ===== iptables 透明代理規則 =====
# 等待 mihomo 啟動
sleep 3

# 清除舊規則（防止重複）
iptables -t nat -F PREROUTING

# HTTP/HTTPS 重定向
iptables -t nat -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING 1 -p tcp --dport 443 -j REDIRECT --to-ports 12348

# DNS 重定向
iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j REDIRECT --to-ports 12348

# 允許區域網
iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I INPUT -s 192.168.0.0/16 -j ACCEPT

exit 0
EOF

chmod +x /etc/rc.local
```

### 5.2 測試腳本

```bash
# 手動執行（不重啟路由器）
/etc/rc.local
```

確認 `docker ps` 有 mihomo，iptables 規則存在：

```bash
iptables -t nat -L PREROUTING -n | grep 12348
```

---

## 第六步：廣告攔截

> 使用 mihomo 的 `ruleset` 規則，配合免費開源廣告列表。

### 6.1 什麼是廣告攔截

在 mihomo 的 `rules` 裏加入 `REJECT` 規則，當流量匹配到廣告域名時，mihomo 直接返回空回應（拒絕連接），而不是轉發到代理節點。

### 6.2 修改配置文件

在本地電腦修改 `~/mihomo_config.yaml`，在 `rules` 最前面加入：

```yaml
# ===== 廣告攔截規則（REJECT = 直接阻擋） =====

# === 常見廣告域名 ===
- DOMAIN-SUFFIX,doubleclick.net,REJECT
- DOMAIN-SUFFIX,googlesyndication.com,REJECT
- DOMAIN-SUFFIX,googleadservices.com,REJECT
- DOMAIN-SUFFIX,moatads.com,REJECT
- DOMAIN-SUFFIX,adnxs.com,REJECT
- DOMAIN-SUFFIX,adsrvr.org,REJECT
- DOMAIN-SUFFIX,advertising.com,REJECT
- DOMAIN-SUFFIX,outbrain.com,REJECT
- DOMAIN-SUFFIX,taboola.com,REJECT
- DOMAIN-SUFFIX,criteo.com,REJECT
- DOMAIN-SUFFIX,criteo.net,REJECT
- DOMAIN-SUFFIX,amazon-adsystem.com,REJECT
- DOMAIN-SUFFIX,media.net,REJECT
- DOMAIN-SUFFIX,popads.net,REJECT
- DOMAIN-SUFFIX,popcash.net,REJECT

# === 中國常見廣告平台 ===
- DOMAIN-SUFFIX,baidustatic.com,REJECT
- DOMAIN-SUFFIX,bdstatic.com,REJECT
- DOMAIN-SUFFIX,hitplan.cn,REJECT
- DOMAIN-SUFFIX,toutiao.com,REJECT
- DOMAIN-SUFFIX,穿山甲聯盟,REJECT

# === APP 開屏廣告 / SDK ===
- DOMAIN-SUFFIX,umeng.com,REJECT
- DOMAIN-SUFFIX,umengcloud.com,REJECT
- DOMAIN-SUFFIX,appsflyer.com,REJECT
- DOMAIN-SUFFIX,adjust.com,REJECT
- DOMAIN-SUFFIX,branch.io,REJECT

# === 追蹤 / Telemetry ===
- DOMAIN-SUFFIX,telemetry.microsoft.com,REJECT
- DOMAIN-SUFFIX,watson.microsoft.com,REJECT
- DOMAIN-SUFFIX,scorecardresearch.com,REJECT
- DOMAIN-SUFFIX,demdex.net,REJECT

# === 規則集（mihomo 高級功能） ===
# 使用 rule-provider 定時自動更新廣告列表
rule-providers:
  reject-ad:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt"
    path: ./rule-providers/reject-ad.yaml
    interval: 86400
  privacy:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/privacy.txt"
    path: ./rule-providers/privacy.yaml
    interval: 86400

rules:
  # 先用規則集過濾
  - RULE-SET,reject-ad,REJECT
  - RULE-SET,privacy,REJECT
```

### 6.3 上傳並重啟

```bash
# 上傳新配置
scp ~/mihomo_config.yaml root@192.168.31.1:/mnt/docker_disk/mi_docker/mihomo_config.yaml

# 重啟 mihomo
ssh root@192.168.31.1 "/mnt/docker_disk/mi_docker/docker-binaries/docker restart mihomo"
```

---

## 第七步：廣告攔截規則

> 如果你想更強的廣告攔截，可以用更多規則列表。

### 7.1 推薦的免費規則集

| 規則名 | URL | 用途 |
|--------|-----|------|
| Loyalsoldier reject | `https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt` | 廣告 + 追蹤 |
| Loyalsoldier privacy | `https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/privacy.txt` | 隱私追蹤 |
| Hackl0us lan | `https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/rule.yaml` | 國內流量直連 |

### 7.2 規則更新

rule-provider 的 `interval: 86400` 是每 24 小時自動更新一次，也可以手動更新：

```bash
ssh root@192.168.31.1
/mnt/docker_disk/mi_docker/docker-binaries/docker exec mihomo mihomo --update-ruleset
```

---

## 節點配置說明

### 如何獲取節點？

1. **機場訂閱** — 大部分機場提供「Clash 訂閱鏈接」，直接導入即可
2. **自建節點** — VMess/VLESS/Trojan，需要自行搭建

### 訂閱轉換（可選）

如果你的機場提供的是 Surge / Shadowrocket 格式，可以用線上工具轉換：
- https://sub.v1.mk
- https://acl4ssr.netlify.app

### 節點格式對照

| 格式 | mihomo 關鍵字 |
|------|--------------|
| VMess | `type: vmess`, `uuid`, `alterId` |
| VLESS | `type: vless`, `uuid` |
| Trojan | `type: trojan`, `password` |
| Shadowsocks | `type: ss`, `cipher`, `password` |

---

## 常見問題

### Q: mihomo 容器自動重啟？
```bash
/mnt/docker_disk/mi_docker/docker-binaries/docker restart mihomo
```

### Q: 想要代理所有流量（不做分流）？
把 `rules` 裏最後一條 `MATCH` 改成：
```yaml
- MATCH,auto   # 所有流量都走 auto 代理組
```

### Q: 想指定某些設備直連？
在路由器添加 iptables 例外：
```bash
# 192.168.31.100 這個設備不走代理
iptables -t nat -I PREROUTING -s 192.168.31.100 -j ACCEPT
```

### Q: 路由器重啟後全部消失？
確認 `/etc/rc.local` 腳本已正確寫入（見 [第五步](#第五步開機自動啟動)）。

### Q: 如何確認代理 IP？
訪問 https://ip.sb 或 https://whatismyip.com，顯示的 IP 即為代理出口 IP。

### Q: 透明代理不生效？
確認 `redir-port: 12348` 存在於 config.yaml，且 iptables 規則有正確寫入：
```bash
iptables -t nat -L PREROUTING -n --line-numbers
```

---

## 附錄 A：跨網段 SSH 問題

### 症狀
SSH 連接 `192.168.31.1` 超時，但同網段的設備可以連接。

### 原因
上層路由器（如 ASUS）的「Martian Filter」/ DoS 防護會 drop 跨網段的 SSH 回應包。

### 解法（任選其一）

**方法一：用 WAN IP SSH（推薦）**
```bash
# AX9000 的 WAN 口 IP（上級路由器分配的）
ssh root@192.168.1.59
```

**方法二：在上層路由器添加 SSH 白名單**
登入上層路由器後台，找到「防火牆 / DoS 防護」設置，將 `192.168.31.0/24` 加入白名單。

**方法三：關閉上級路由器的 Martini Filter**
```bash
# 在上級路由器（ASUS）執行
iptables -I FORWARD -s 192.168.31.0/24 -p tcp --dport 22 -j ACCEPT
```

---

## 附錄 B：一鍵完整部署腳本

> ⚠️ 使用前請先修改配置文件中的 `YOUR_UUID_HERE` 等佔位符

在 `/mnt/docker_disk/mi_docker/setup.sh` 保存以下內容，SSH 進去後執行 `bash /mnt/docker_disk/mi_docker/setup.sh`

```bash
#!/bin/bash
set -e

echo "[1/6] 下載 Docker..."
mkdir -p /mnt/docker_disk/mi_docker/docker-binaries
cd /mnt/docker_disk/mi_docker/docker-binaries
curl -fsSL "https://download.docker.com/linux/static/stable/aarch64/docker-26.1.0.tgz" | tar xz
chmod +x docker/*
echo "Docker 下載完成"

echo "[2/6] 啟動 Docker daemon..."
./dockerd > /dev/null 2>&1 &
sleep 5

echo "[3/6] 拉取 mihomo 鏡像..."
./docker pull metacubex/mihomo:latest

echo "[4/6] 啟動 mihomo 容器..."
cd /mnt/docker_disk/mi_docker
./docker-binaries/docker run -d \
  --name mihomo \
  --restart unless-stopped \
  -v /mnt/docker_disk/mi_docker/mihomo_config.yaml:/config.yaml \
  -p 12346:12346 -p 12347:12347 -p 12348:12348 -p 9090:9090 \
  metacubex/mihomo:latest

echo "[5/6] 配置 iptables 透明代理..."
sleep 3
iptables -t nat -F PREROUTING
iptables -t nat -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING 1 -p tcp --dport 443 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j REDIRECT --to-ports 12348
iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I INPUT -s 192.168.0.0/16 -j ACCEPT

echo "[6/6] 完成！"
./docker ps
iptables -t nat -L PREROUTING -n | grep 12348
echo "部署完成 🎉"
```

---

## License

MIT — 學習交流使用，請勿用於非法用途。
