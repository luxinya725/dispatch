#!/usr/bin/env bash
# Dispatch 一键启动：Redis + 后端(8000) + 前端(5173)
set -e
ROOT="$(cd "$(dirname "$0")" && pwd)"

# 1. Redis
if ! redis-cli ping >/dev/null 2>&1; then
  echo "启动 Redis..."
  redis-server --port 6379 --daemonize yes --save "" --appendonly no
  sleep 1
fi
echo "Redis: $(redis-cli ping)"

# 2. 后端
if lsof -ti:8000 >/dev/null 2>&1; then
  echo "后端已在 8000 运行，跳过"
else
  echo "启动后端..."
  cd "$ROOT/backend"
  nohup .venv/bin/python api/main.py > /tmp/dispatch-backend.log 2>&1 &
  sleep 8
  echo "后端日志: /tmp/dispatch-backend.log"
fi
curl -s http://localhost:8000/health >/dev/null && echo "后端: ok (http://localhost:8000)"

# 3. 前端
if lsof -ti:5173 >/dev/null 2>&1; then
  echo "前端已在 5173 运行，跳过"
else
  echo "启动前端..."
  cd "$ROOT/frontend"
  nohup npm run dev > /tmp/dispatch-frontend.log 2>&1 &
  sleep 4
fi
echo "前端: http://localhost:5173"
