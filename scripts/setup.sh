#!/bin/bash
# ============================================================
# 小米 AX9000 — mihomo Docker 一鍵部署腳本
# 使用前：先上傳 mihomo_config.yaml 到 /mnt/docker_disk/mi_docker/
# ============================================================
set -e

CONFIG_PATH="/mnt/docker_disk/mi_docker/mihomo_config.yaml"
DOCKER_DIR="/mnt/docker_disk/mi_docker/docker-binaries"
MIHOMO_PORT=12348
API_PORT=9090

echo "=============================="
echo "AX9000 mihomo Docker 部署腳本"
echo "=============================="

# 檢查配置文件是否存在
if [ ! -f "$CONFIG_PATH" ]; then
    echo "[錯誤] 找不到配置文件: $CONFIG_PATH"
    echo "請先上傳 mihomo_config.yaml 到 AX9000"
    exit 1
fi

echo "[1/7] 創建目錄..."
mkdir -p "$DOCKER_DIR"

echo "[2/7] 檢查 Docker 是否已安裝..."
if [ ! -f "$DOCKER_DIR/docker" ]; then
    echo "    Docker 未安裝，正在下載..."
    cd "$DOCKER_DIR"
    curl -fsSL "https://download.docker.com/linux/static/stable/aarch64/docker-26.1.0.tgz" | tar xz
    chmod +x "$DOCKER_DIR/docker"*
    echo "    Docker 下載完成"
else
    echo "    Docker 已存在，跳過下載"
fi

echo "[3/7] 啟動 Docker daemon..."
if ! pgrep -x dockerd > /dev/null; then
    "$DOCKER_DIR/dockerd" > /dev/null 2>&1 &
    sleep 5
    echo "    Docker daemon 已啟動"
else
    echo "    Docker daemon 已在運行"
fi

echo "[4/7] 拉取 mihomo 鏡像..."
"$DOCKER_DIR/docker" pull metacubex/mihomo:latest

echo "[5/7] 停止並刪除舊容器（如存在）..."
"$DOCKER_DIR/docker" stop mihomo 2>/dev/null || true
"$DOCKER_DIR/docker" rm mihomo 2>/dev/null || true

echo "[6/7] 啟動 mihomo 容器..."
cd /mnt/docker_disk/mi_docker
"$DOCKER_DIR/docker" run -d \
    --name mihomo \
    --restart unless-stopped \
    -v "$CONFIG_PATH:/config.yaml" \
    -p 12346:12346 \
    -p 12347:12347 \
    -p ${MIHOMO_PORT}:${MIHOMO_PORT} \
    -p ${API_PORT}:${API_PORT} \
    metacubex/mihomo:latest

echo "[7/7] 配置 iptables 透明代理..."
sleep 3

# 清除舊規則
iptables -t nat -F PREROUTING 2>/dev/null || true

# HTTP/HTTPS 重定向
iptables -t nat -I PREROUTING 1 -p tcp --dport 80 -j REDIRECT --to-ports ${MIHOMO_PORT}
iptables -t nat -I PREROUTING 1 -p tcp --dport 443 -j REDIRECT --to-ports ${MIHOMO_PORT}

# DNS 重定向
iptables -t nat -I PREROUTING 1 -p udp --dport 53 -j REDIRECT --to-ports ${MIHOMO_PORT}

# 允許區域網
iptables -I INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || true
iptables -I INPUT -s 192.168.0.0/16 -j ACCEPT 2>/dev/null || true

echo ""
echo "=============================="
echo "🎉 部署完成！"
echo "=============================="
echo ""
echo "mihomo 容器狀態："
"$DOCKER_DIR/docker" ps --filter "name=mihomo"
echo ""
echo "透明代理端口：$MIHOMO_PORT"
echo "HTTP 代理端口：12346"
echo "API 管理端口：$API_PORT"
echo ""
echo "測試透明代理："
echo "  curl -x http://192.168.31.1:12346 https://api.openai.com/v1/models"
echo ""
echo "查看容器日誌："
echo "  docker logs mihomo --tail 20"
echo ""
