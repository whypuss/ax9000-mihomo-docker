# 🛡️ 廣告攔截配置指南

> mihomo 內置 REJECT 規則 + rule-provider 自動更新列表

---

## 原理

mihomo 的 `rules` 裏，`REJECT` 表示直接阻擋連接（返回空回應），而不是轉發到代理節點。

瀏覽器視圖：廣告域名 → mihomo REJECT → 連接失敗 = 無廣告

---

## 方法一：手動添加 REJECT 規則（最簡單）

直接在 `mihomo_config.yaml` 的 `rules` 部分加入：

```yaml
rules:
  # === 廣告域名 ===
  - DOMAIN-SUFFIX,doubleclick.net,REJECT
  - DOMAIN-SUFFIX,googlesyndication.com,REJECT
  - DOMAIN-SUFFIX,googleadservices.com,REJECT
  - DOMAIN-SUFFIX,moatads.com,REJECT
  - DOMAIN-SUFFIX,adnxs.com,REJECT
  - DOMAIN-SUFFIX,adsrvr.org,REJECT
  - DOMAIN-SUFFIX,advertising.com,REJECT
  - DOMAIN-SUFFIX,criteo.com,REJECT
  - DOMAIN-SUFFIX,criteo.net,REJECT
  - DOMAIN-SUFFIX,amazon-adsystem.com,REJECT
  - DOMAIN-SUFFIX,outbrain.com,REJECT
  - DOMAIN-SUFFIX,taboola.com,REJECT
  - DOMAIN-SUFFIX,media.net,REJECT
  - DOMAIN-SUFFIX,popads.net,REJECT
  - DOMAIN-SUFFIX,popcash.net,REJECT

  # === 中國平台廣告 ===
  - DOMAIN-SUFFIX,baidustatic.com,REJECT
  - DOMAIN-SUFFIX,bdstatic.com,REJECT
  - DOMAIN-SUFFIX,hitplan.cn,REJECT

  # === APP SDK 廣告 ===
  - DOMAIN-SUFFIX,umeng.com,REJECT
  - DOMAIN-SUFFIX,umengcloud.com,REJECT
  - DOMAIN-SUFFIX,appsflyer.com,REJECT
  - DOMAIN-SUFFIX,adjust.com,REJECT
  - DOMAIN-SUFFIX,branch.io,REJECT

  # === 追蹤 telemetry ===
  - DOMAIN-SUFFIX,telemetry.microsoft.com,REJECT
  - DOMAIN-SUFFIX,watson.microsoft.com,REJECT
  - DOMAIN-SUFFIX,scorecardresearch.com,REJECT
  - DOMAIN-SUFFIX,demdex.net,REJECT

  # === 你的分流規則... ===
  - DOMAIN-SUFFIX,chatgpt.com,auto
  # ...
```

---

## 方法二：rule-provider 自動更新（推薦）

mihomo 支持從 URL 自動下載規則列表，每 24 小時更新一次。

### 在 config.yaml 添加：

```yaml
# ===== 規則集提供者 =====
rule-providers:
  # 廣告 + 追蹤攔截
  reject-ad:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt"
    path: ./rule-providers/reject-ad.yaml
    interval: 86400        # 每 24 小時更新

  # 隱私追蹤
  privacy:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/privacy.txt"
    path: ./rule-providers/privacy.yaml
    interval: 86400

# ===== 規則中使用規則集 =====
rules:
  # 放在最前面，廣告先攔截
  - RULE-SET,reject-ad,REJECT
  - RULE-SET,privacy,REJECT

  # 你的其他規則...
  - DOMAIN-SUFFIX,chatgpt.com,auto
  - MATCH,auto
```

### 創建 rule-providers 目錄

```bash
# SSH 進 AX9000
ssh root@192.168.1.59

# 創建目錄（mihomo 容器內的路徑）
mkdir -p /mnt/docker_disk/mi_docker/rule-providers
```

### 重啟 mihomo 生效

```bash
docker restart mihomo
```

---

## 方法三：完整的分流 + 廣告配置示例

```yaml
# config.yaml 完整示例（包含分流 + 廣告 + 代理組）

port: 12346
socks-port: 12347
mixed-port: 0
redir-port: 12348
allow-lan: true
mode: rule
log-level: info
external-controller: 0.0.0.0:9090

dns:
  enable: true
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - 8.8.8.8
    - 8.8.4.4
  fallback:
    - 1.1.1.1
    - 1.0.0.1

# === 節點（填入你的真實節點） ===
proxies:
  - name: 日本節點
    type: vless
    server: your-server.jp
    port: 443
    uuid: YOUR-UUID-HERE
    network: ws
    tls: true
    sni: your-server.jp
    ws-opts:
      path: "/"
      headers:
        Host: your-server.jp

proxy-groups:
  - name: auto
    type: select
    proxies:
      - 日本節點

# === 規則集 ===
rule-providers:
  reject-ad:
    type: http
    behavior: domain
    url: "https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt"
    path: ./rule-providers/reject-ad.yaml
    interval: 86400

rules:
  # 1. 廣告攔截（最優先）
  - RULE-SET,reject-ad,REJECT

  # 2. AI 服務走代理
  - DOMAIN-SUFFIX,chatgpt.com,auto
  - DOMAIN-SUFFIX,claude.ai,auto
  - DOMAIN-SUFFIX,anthropic.com,auto
  - DOMAIN-SUFFIX,gemini.google.com,auto

  # 3. 社交媒體
  - DOMAIN-SUFFIX,x.com,auto
  - DOMAIN-SUFFIX,twitter.com,auto

  # 4. 默認：直連（中國流量不走代理）
  - MATCH,DIRECT
```

---

## 推薦的規則集 URL

| 用途 | URL |
|------|-----|
| 廣告 + 追蹤 | `https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/reject.txt` |
| 隱私追蹤 | `https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/privacy.txt` |
| 中國流量直連 | `https://raw.githubusercontent.com/Hackl0us/GeoIP2-CN/release/rule.yaml` |
| 全套規則 | `https://raw.githubusercontent.com/Loyalsoldier/clash-rules/release/ruleset.yaml` |

---

## 測試廣告攔截是否生效

```bash
# 在路由器測試（REJECT 會立即返回）
ssh root@192.168.1.59
curl -x http://127.0.0.1:12346 http://doubleclick.net -I --connect-timeout 3
# 如果返回類似 "Connection refused" 或超時，表示 REJECT 生效

# 查看 mihomo 日誌（有 REJECT 記錄）
docker logs mihomo --tail 50 | grep REJECT
```

---

## 注意事項

1. **REJECT 會讓瀏覽器報錯** — 部分網站引入第三方廣告域名後，REJECT 可能導致頁面載入慢或部分內容顯示不了。把這些域名加到 `DIRECT` 可以解決。

2. **不要 REJECT 太多** — 太多 REJECT 規則會佔用記憶體。建議只用 rule-provider 的拒絕列表。

3. **更新頻率** — `interval: 86400` 是 24 小時，想快點可以改成 3600（1 小時），但太頻繁會觸發 GitHub 限速。

4. **規則衝突** — `RULE-SET` 和 `DOMAIN-SUFFIX` 同時存在時，按順序匹配，第一條匹配就執行。
