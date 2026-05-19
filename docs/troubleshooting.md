# 🔧 常見問題排錯

---

## 1. SSH 連不上

### 症狀：`Connection timed out` 或 `Permission denied`

**檢查清單：**
- [ ] 電腦和 AX9000 在同一網段（同一路由器/WiFi）
- [ ] 嘗試 `192.168.31.1` 和 `192.168.1.59` 兩個 IP
- [ ] SSH 密碼正確

**解決方法：**
```bash
# 方法1：用 WAN IP（推薦，避開上層路由器防火牆）
ssh root@192.168.1.59

# 方法2：在上級路由器開 SSH 白名單
# ASUS 登入後台 → 防火牆 → 關閉 Martini Filter
# 或執行：
iptables -I FORWARD -s 192.168.31.0/24 -p tcp --dport 22 -j ACCEPT
```

---

## 2. Docker 下載失敗

### 症狀：`curl: (7) Failed to connect` 或 `curl: (22) The requested URL returned error: 404`

**原因：** AX9000 是 `aarch64`（ARM64）架構，不能用 x86 的 Docker。

**解決：**
確認使用 aarch64 链接：
```bash
curl -fsSL "https://download.docker.com/linux/static/stable/aarch64/docker-26.1.0.tgz" | tar xz
```
如果 404，去 https://download.docker.com/linux/static/stable/aarch64/ 查看最新版本。

---

## 3. mihomo 容器啟動後立即退出

### 症狀：`docker ps` 找不到容器，或 `docker logs mihomo` 顯示錯誤

**第一步：看日誌**
```bash
/mnt/docker_disk/mi_docker/docker-binaries/docker logs mihomo
```

**常見錯誤：**

#### YAML 格式錯誤
```
yaml: line 42: did not find expected key
```
→ config.yaml 有縮進或語法錯誤，檢查 `proxies:` 和 `rules:` 的格式。

#### UUID / 密碼錯誤
```
Error: uuid/secret format error
```
→ 檢查節點配置中的 UUID 或密碼是否正確。

#### 端口被佔用
```
Error: port 12346 already in use
```
→ 殺掉佔用端口的進程：
```bash
fuser -k 12346/tcp
```

---

## 4. 透明代理不生效

### 症狀：設置了代理但瀏覽器依然直連（IP 沒變）

**第一步：確認 iptables 規則存在**
```bash
iptables -t nat -L PREROUTING -n --line-numbers | grep 12348
```

如果沒有輸出，規則沒寫入：
```bash
# 重新寫入
iptables -t nat -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING 1 -p tcp --dport 443 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j REDIRECT --to-ports 12348
```

**第二步：確認 mihomo 的 redir-port 開了**
```bash
# 在 config.yaml 裏確認有這行：
# redir-port: 12348
```

**第三步：確認 mihomo 在轉發**
```bash
# 看 docker logs 有流量
/mnt/docker_disk/mi_docker/docker-binaries/docker logs mihomo --tail 20
```

---

## 5. 路由器重啟後全部消失

### 原因：AX9000 重啟後內存會清空，rc.local 沒設置正確

**檢查 rc.local 是否存在：**
```bash
cat /etc/rc.local
```

如果沒有或內容不對，重新寫入：
```bash
cat > /etc/rc.local << 'EOF'
#!/bin/sh
sleep 15
/mnt/docker_disk/mi_docker/docker-binaries/dockerd > /dev/null 2>&1 &
sleep 8
cd /mnt/docker_disk/mi_docker
/mnt/docker_disk/mi_docker/docker-binaries/docker start mihomo 2>/dev/null || \
  /mnt/docker_disk/mi_docker/docker-binaries/docker run -d \
    --name mihomo --restart unless-stopped \
    -v /mnt/docker_disk/mi_docker/mihomo_config.yaml:/config.yaml \
    -p 12346:12346 -p 12347:12347 -p 12348:12348 -p 9090:9090 \
    metacubex/mihomo:latest
sleep 5
iptables -t nat -F PREROUTING
iptables -t nat -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING 1 -p tcp --dport 443 -j REDIRECT --to-ports 12348
iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j REDIRECT --to-ports 12348
iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -I INPUT -s 192.168.0.0/16 -j ACCEPT
exit 0
EOF

chmod +x /etc/rc.local
```

---

## 6. 節點延遲高或無法連接

### 檢查節點狀態

```bash
# 用 mihomo API 查看延遲
curl -s http://192.168.31.1:9090/proxies
```

在瀏覽器打開 `http://192.168.31.1:9090` 使用 Web UI 切換節點。

### 測試單一節點
```bash
curl -x http://192.168.31.1:12346 https://www.google.com -I
```

---

## 7. 想取消透明代理

```bash
# 清除所有轉發規則
iptables -t nat -F PREROUTING

# 清除 INPUT 規則
iptables -F INPUT

# 停止 mihomo
/mnt/docker_disk/mi_docker/docker-binaries/docker stop mihomo
```

---

## 8. 更新 mihomo 容器

```bash
/mnt/docker_disk/mi_docker/docker-binaries/docker pull metacubex/mihomo:latest
/mnt/docker_disk/mi_docker/docker-binaries/docker stop mihomo
/mnt/docker_disk/mi_docker/docker-binaries/docker rm mihomo
# 然後重新運行啟動命令（見 quickstart.md Step 3）
```

---

## 快速診斷命令清單

```bash
# 1. SSH 進路由器
ssh root@192.168.1.59

# 2. 查看 mihomo 容器狀態
/mnt/docker_disk/mi_docker/docker-binaries/docker ps

# 3. 查看容器日誌
/mnt/docker_disk/mi_docker/docker-binaries/docker logs mihomo --tail 30

# 4. 查看 iptables 規則
iptables -t nat -L PREROUTING -n --line-numbers

# 5. 重啟 mihomo
/mnt/docker_disk/mi_docker/docker-binaries/docker restart mihomo

# 6. 查看 mihomo API
curl -s http://192.168.31.1:9090/proxies | python3 -m json.tool 2>/dev/null || echo "API 不可用"
```
