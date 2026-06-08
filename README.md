# 小米 AX9000 宿主機免 Docker 透明代理 (Mihomo Base)

本項目專門為 **小米路由器 AX9000 (RA70, 內置 802MB RAM, Linux 核心 Kernel 4.4.60)** 客製化一套高能高效、無縫安全、**完全免本機/手機設置** 的透明代理 (Transparent Proxy)。

---

## 🚨 核心避坑紅線（必讀）

### 🛑 1. 為什麼必須棄用 Docker？（記憶體崩潰鎖死坑）
AX9000 雖然配置了 Docker 環境，但其 RAM 只有 **802MB**。在 Docker 運作時，單是 `containerd` 守護進程的常駐記憶體（RSS）便可吞噬近 **998MB**！這會引發嚴重的 **OOM (Out of Memory) 鎖死重啟**。
**唯一最安全的法門：** 放棄 Docker 容器，**直接在小米路由器宿主磁碟上加載、運行單個輕量 Mihomo 二進制服務**（平常 RSS 僅耗 ~100MB 左右）。

### 🛑 2. 為什麼不能在舊核心下使用 TUN 網卡模式？
小米官方 Kernel 版本是 4.4.60，內核過舊。在此核心下開啟 TUN 虛擬網卡（如 Meta）並架設 IP 規則，會引發無線 WiFi 晶片發起 Client Auth/Deauth 狂躁連鎖反应，導致局域網設備无限重連與 WiFi 網絡黑洞。
**唯一解決方法：** 採用純 **iptables PREROUTING REDIRECT (TCP 12348)** + **UDP DNS 攔截 (1053)** 的透明劫持架構。

### 🛑 3. 網遊與國內 App 被代理接管坑（王者、和平、微信、支付寶免 Fake-IP 實戰）
雖然很多透明代理支持 GeoIP 分流（國內流量 DIRECT），但在 Fake-IP 模式下：
- 所有國內域名默認依然會被分配一個 `198.18.x.x` (Fake-IP) 假 IP。
- 手機對這些 Fake-IP 發起連線時，會被 mihomo 的 iptables 強行攔截、建立中轉握手、再由 mihomo 通過本地連線直連。
- **這種「假直連」對即時網絡手遊（如王者榮耀、和平精英）是致命的！** 它會造成 **Ping 延遲暴增、網絡不穩、微信支付偶發性假死、以及大量的路由器 CPU 負載消耗**。
- **唯一完美的根治秘決：** 必須把中國各大高流量巨頭域名（騰訊、阿里、微信、支付寶、抖音、美團等）**全數寫入 `fake-ip-filter` 免 Fake-IP 白名單中**。
- 這樣一來，DNS 會直接返回真實的中國公網物理 IP，手機發起連線時**直接觸發 Linux 本地 Native 硬件物理直連，完全不經 mihomo 握手二次接管，100% 降底 Ping 值與保證免代原生流暢**！

### 🛑 4. Google 基礎登錄認證與 Secure DNS (DoH/DoT) 劫持超時坑
當我們為了省流、把所有非 AI 全球流量一律改為 `DIRECT` 直連時：
- 瀏覽器在進入 **Google AI Studio (`aistudio.google.com/projects`)** 或者是查看地區文件 **(`ai.google.dev`)** 時，後台會頻繁核驗你 Google 帳戶的 Session Cookie (向 `accounts.google.com` 登錄端) 及拉取安全代碼 (向 `gstatic.com` 靜態 CDN 端)；
- 更為致命的是：Chrome 會默認向 Google 安全 DNS **`dns.google` (8.8.8.8 等)** 建立 DoH 或 DoT 安全加密握手來解析網域。
- 如果這類 Google 基礎域名和 DoH 被一刀切到 `DIRECT` 直連，在大陸/香港或直連受阻的環境，這類 Google 核心網卡連線會 100% Timeout 阻斷。前端始終拿不到認證碼，**於是便會產生 AI Studio 首頁無限轉圈卡死、可用地區文檔打不開的詭異故障**。
- **最完美的割裂策略：** 必須在 rules 段內，將所有含有 `google`、`googleapis` 核心關鍵字及它的 `gstatic` 等核心後綴指向海外代理。而在前置位置優先過濾 YouTube 視頻 (googlevideo.com / youtube.com 等) 為 `DIRECT`。
- 這樣既打通了 Google 全家桶的 API 認證、解決了安全 Domain 解析超時；又 100% 隔離了 YouTube 超大帶寬消費，完美守住你的代理流量！

---

## 🏆 攻克 Claude.ai 403 Forbidden 兩大「指紋」神技

很多人發現用 Xray 或常規透明代理雖然能上 ChatGPT，但一存取 `claude.ai` 便會立刻返回 **HTTP 403 Forbidden**（哪怕你手機開 v2ray 用同一個節點十分流暢）。這是因為 **Cloudflare/Claude 擁有全球最嚴格的網域與 TLS 指紋風控 WAF**！

本項目透過全網率先攻佔以下兩點解決此問題：

### 🎯 特效 A. 剔除 DNS Fake-IP Filter 白名單（保留 Domain 信息）
在舊 Linux 4.4.60 核心下，Mihomo 沒法自主、成功地在 TCP 鏈中嗅探（Sniffing）出 HTTPS 的真正 TLS Host Name 域名。
- 如果你把 `claude.ai`、`chatgpt.com` 塞在 `fake-ip-filter` 內，路由器解析時會直接返回 True-IP。
- 當設備以 IP 發起連線時，Mihomo 只收到 target IP（如 `160.79.104.10`）而失去了 Domain 信息。
- 這樣 Mihomo 在 outbound 出口握手時發送不出正確的 SNI，Cloudflare WAF 直接將其視為惡意嗅探封鎖 (403)！
- **解決方針**：**絕對不能在 `fake-ip-filter` 白名單中放任何 AI 網域**！使它們 100% 走 Fake-IP 解析取得 `198.18.x.x`，從而能被 100% 還原出正確網域名稱！

### 🎯 特效 B. 模擬 Chrome 瀏覽器極致指紋 (uTLS / client-fingerprint)
- 行動端常規 v2ray / Shadowrocket App 在出站握手時，默認會用 uTLS 進行 Chrome 瀏覽器 TLS Hello 包模擬。
- 但如果在路由器不寫，Golang 就會使用裸 OpenSSL/Golang Client Hello 組包。Cloudflare 發現 TLS 指紋與 IP 出處（黑客 VPS）不符，就會丟出 403。
- **解決方針**：在 `configs/mihomo_config_template.yaml` 內之 VLESS 節點下，**強大追加 `client-fingerprint: chrome`**，抹平所有代理與瀏覽器指紋特徵差！

---

## 🛠️ 下載與快速署安裝步驟

### 1. 獲取宿主機運行二進制
將適配 AX9000 CPU (Arm64) 嘅 Mihomo 二進制放置於實體磁碟目錄中，例如 `/extdisks/sda1/mi_docker/mihomo`。

### 2. 獲取配置模板並填入節點
下載本倉庫 `configs/mihomo_config_template.yaml` 至本機，將 VLESS 節點的真實 `server`、`uuid`、`password` 等 placeholders 替換。並保存為 `/extdisks/sda1/mi_docker/config.yaml` 或者是 `mihomo_config.yaml`。

```bash
# 確保文件存放在宿主機硬盤
ls -la /extdisks/sda1/mi_docker/config.yaml
```

### 3. 配置自啟啟動外殼 `/tmp/run_mihomo.sh`
建立這個細小外殼，目的是在啟動前**突破 Linux 預設 1024 fd limit (防止 socket 溢出報錯 too many open files)**：

```bash
#!/bin/sh
ulimit -n 65535
exec /extdisks/sda1/mi_docker/mihomo -d /extdisks/sda1/mi_docker/ >> /tmp/mihomo.log 2>&1
```

### 4. 加載 `/etc/rc.local` 開機自動導流
編輯小米路由器的 `/etc/rc.local`，內容如下：

```bash
#!/bin/sh

# 1. 突破進程 File Descriptor 上限
ulimit -n 65535

# 2. 清理可能殘留的舊 Docker/消防牆
iptables -t nat -D PREROUTING -s 192.168.31.0/24 -p udp --dport 53 -j REDIRECT --to-ports 1053 2>/dev/null || true
iptables -t nat -D PREROUTING -s 192.168.31.0/24 ! -d 192.168.31.0/24 -p tcp --dport 443 -j REDIRECT --to-ports 12348 2>/dev/null || true
iptables -t nat -D PREROUTING -s 192.168.31.0/24 ! -d 192.168.31.0/24 -p tcp --dport 80 -j REDIRECT --to-ports 12348 2>/dev/null || true

# 3. 強制所有局域網設備 DNS UDP 流量走 1053 Fake-IP 映射 (全面掌控)
iptables -t nat -I PREROUTING -s 192.168.31.0/24 -p udp --dport 53 -j REDIRECT --to-ports 1053

# 4. 全局將 LAN 設備 (191.168.31.0/24) 80/443 TCP 重定向到 12348 REDIR
iptables -t nat -I PREROUTING -s 192.168.31.0/24 ! -d 192.168.31.0/24 -p tcp --dport 443 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING -s 192.168.31.0/24 ! -d 192.168.31.0/24 -p tcp --dport 80 -j REDIRECT --to-ports 12348

# 5. 後台拉起守護
start-stop-daemon -S -b -m -p /extdisks/sda1/mi_docker/mihomo.pid -x /tmp/run_mihomo.sh

exit 0
```

---

## 🧪 兩秒自我驗證 (Verify Verification)

1. **埠口健康狀態**：
   在 router command 執行：
   ```bash
   netstat -tulanp | grep -E "mihomo"
   ```
   *必須見到 `tcp :::1053`，`udp :::1053`，和 `tcp :::12348` (REDIR) 健在傾聽。*

2. **DNS 劫持反查**：
   在任何 Wi-Fi 連入設備上，執行：
   ```bash
   nslookup claude.ai
   ```
   *Address 1 必須返回 **`198.18.x.x`** 的 Fake-IP。如果還是 `160.79.x.x` 解析，重置或檢查對 53 端口的 UDP PREROUTING REDIRECT 重定向！*

3. **雙重極致測試**：
   在 Mac 終端執行：
   ```bash
   curl -I https://claude.ai/
   ```
   *此時應完美返回 **HTTP 200 / 301 / 302**！403 在此不攻自破！*
