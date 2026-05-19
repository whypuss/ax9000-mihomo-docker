# 🚀 三分鐘快速上手

> 如果你已經有 mihomo_config.yaml，只看這篇

---

## 只需要三步

### Step 1：SSH 進路由器

```bash
ssh root@192.168.31.1
# 密碼：你的SSH密碼
```

> 如果 `192.168.31.1` 連不上，試 `ssh root@192.168.1.59`

---

### Step 2：執行這三行命令

```bash
# 創建目錄
mkdir -p /mnt/docker_disk/mi_docker/docker-binaries

# 下載 Docker
curl -fsSL "https://download.docker.com/linux/static/stable/aarch64/docker-26.1.0.tgz" | tar xz -C /mnt/docker_disk/mi_docker/docker-binaries
chmod +x /mnt/docker_disk/mi_docker/docker-binaries/docker*

# 啟動 Docker
/mnt/docker_disk/mi_docker/docker-binaries/dockerd > /dev/null 2>&1 &
sleep 5
```

---

### Step 3：啟動 mihomo

```bash
/mnt/docker_disk/mi_docker/docker-binaries/docker run -d \
  --name mihomo \
  --restart unless-stopped \
  -v /mnt/docker_disk/mi_docker/mihomo_config.yaml:/config.yaml \
  -p 12346:12346 -p 12347:12347 -p 12348:12348 -p 9090:9090 \
  metacubex/mihomo:latest
```

---

## 完成！測試一下

打開瀏覽器訪問 `https://chatgpt.com`，應該可以了。

如果不行，見 [troubleshooting.md](./troubleshooting.md)
