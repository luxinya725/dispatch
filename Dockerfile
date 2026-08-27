# Dispatch — 单容器部署（前端构建产物由 FastAPI 一起托管）
# 适用于 Hugging Face Spaces (Docker SDK) / Cloud Run / 任何支持 Docker 的平台

# ── 阶段一：构建前端 ──────────────────────────────────────────────────────────
FROM node:20-slim AS frontend
WORKDIR /build
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# ── 阶段二：运行时 ────────────────────────────────────────────────────────────
FROM python:3.12-slim
WORKDIR /app

# HF Spaces 以非 root 用户运行，缓存目录需可写
ENV HOME=/app \
    PYTHONUNBUFFERED=1 \
    ANONYMIZED_TELEMETRY=False

COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ ./

# 预下载向量模型（约 166MB），避免首次请求时才下载导致超时
RUN python -c "from chromadb.utils import embedding_functions as ef; ef.ONNXMiniLM_L6_V2()._download_model_if_not_exists()" \
    || echo "模型预下载失败，运行时会自动下载"

# 前端构建产物
COPY --from=frontend /build/dist ./static

# 部署环境默认值：无 Redis（走内存降级）、数据写入容器内路径
ENV REDIS_URL="" \
    CHROMA_PERSIST_DIRECTORY=/app/data/chroma \
    EVAL_BASELINE_PATH=/app/data/eval/baseline.json \
    FRONTEND_DIST=/app/static \
    PROMETHEUS_PORT=0 \
    CHAT_RATE_LIMIT="20/hour" \
    API_HOST=0.0.0.0 \
    API_PORT=7860

# HF Spaces 约定端口 7860
EXPOSE 7860

CMD ["python", "api/main.py"]
