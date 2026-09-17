#!/usr/bin/env bash
# Dispatch 一键部署脚本（Ubuntu / Debian 服务器）
# 用法：git clone https://github.com/luxinya725/dispatch.git && cd dispatch && bash deploy.sh
set -e

echo "========================================"
echo "  Dispatch 一键部署"
echo "========================================"
echo

# ── 1. 基础工具 ────────────────────────────────────────────────────────────────
echo "[1/5] 检查基础工具..."
if ! command -v git >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq git curl
fi

# ── 2. Docker ──────────────────────────────────────────────────────────────────
if command -v docker >/dev/null 2>&1; then
  echo "[2/5] Docker 已安装：$(docker --version)"
else
  echo "[2/5] 安装 Docker（约 1 分钟）..."
  curl -fsSL https://get.docker.com | sudo sh
fi
sudo systemctl enable --now docker >/dev/null 2>&1 || true

# ── 3. API Key ─────────────────────────────────────────────────────────────────
echo
echo "[3/5] 配置模型 API Key"
echo "      Key 只写入本机的 .env 文件，不会上传到任何地方。"
read -r -s -p "      请粘贴 DeepSeek API Key（输入不回显，粘贴后按回车）: " API_KEY
echo
if [ -z "$API_KEY" ]; then
  echo "❌ Key 不能为空，退出。"
  exit 1
fi

cat > .env.deploy <<EOF
ANTHROPIC_API_KEY=$API_KEY
ANTHROPIC_MODEL=deepseek-chat
ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
PORT=8000
CHAT_RATE_LIMIT=20/hour
EOF
chmod 600 .env.deploy
echo "      ✅ 已写入 .env.deploy（权限 600，仅本用户可读）"

# ── 4. 构建镜像 ────────────────────────────────────────────────────────────────
echo
echo "[4/5] 构建 Docker 镜像（首次约 5-10 分钟，含下载 166MB 向量模型）..."
sudo docker build -t dispatch:latest . 2>&1 | grep -E "Step|Successfully|ERROR|error" || true
echo "      ✅ 镜像构建完成"

# ── 5. 启动服务 ────────────────────────────────────────────────────────────────
echo
echo "[5/5] 启动服务..."
sudo docker rm -f dispatch >/dev/null 2>&1 || true
sudo docker run -d \
  --name dispatch \
  --restart unless-stopped \
  -p 80:8000 \
  --env-file .env.deploy \
  dispatch:latest >/dev/null

echo "      等待服务就绪（加载向量模型约 20 秒）..."
for i in $(seq 1 30); do
  if curl -sf http://localhost/health >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# ── 验证 ───────────────────────────────────────────────────────────────────────
echo
echo "========================================"
if curl -sf http://localhost/health >/dev/null 2>&1; then
  PUBLIC_IP=$(curl -s --max-time 5 https://ipinfo.io/ip || curl -s --max-time 5 https://api.ipify.org || echo "<你的公网IP>")
  echo "  ✅ 部署成功！"
  echo
  echo "  访问地址：http://$PUBLIC_IP"
  echo
  echo "  常用命令："
  echo "    查看日志：sudo docker logs -f dispatch"
  echo "    重启服务：sudo docker restart dispatch"
  echo "    更新代码：git pull && bash deploy.sh"
  echo
  echo "  ⚠️  请确认腾讯云控制台「防火墙」已放行 80 端口"
else
  echo "  ❌ 服务未能就绪，查看日志排查："
  echo "     sudo docker logs dispatch"
fi
echo "========================================"
