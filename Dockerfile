# Dispatch — 单容器部署（前端构建产物由 FastAPI 一起托管）
# 适用于 Hugging Face Spaces (Docker SDK) / Cloud Run / 任何支持 Docker 的平台

# 镜像源（可选）：在中国大陆 / 香港等到官方源不畅的环境，通过 --build-arg 切换。
#   --build-arg NPM_REGISTRY=https://mirrors.cloud.tencent.com/npm/
#   --build-arg PIP_INDEX_URL=https://mirrors.cloud.tencent.com/pypi/simple
ARG NPM_REGISTRY=https://registry.npmjs.org/
ARG PIP_INDEX_URL=https://pypi.org/simple

# ── 阶段一：构建前端 ──────────────────────────────────────────────────────────
FROM node:20-slim AS frontend
ARG NPM_REGISTRY
WORKDIR /build
COPY frontend/package*.json ./
RUN npm config set registry "$NPM_REGISTRY" && npm ci
COPY frontend/ ./
RUN npm run build

# ── 阶段二：运行时 ────────────────────────────────────────────────────────────
FROM python:3.12-slim
ARG PIP_INDEX_URL
ENV PIP_INDEX_URL=$PIP_INDEX_URL

# HF Spaces 以 uid 1000 的非 root 用户运行容器。
# 必须建同名用户并保证工作目录可写，否则 ChromaDB 建库、模型缓存都会因权限失败。
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    ANONYMIZED_TELEMETRY=False

WORKDIR $HOME/app

COPY --chown=user backend/requirements.txt ./
RUN pip install --no-cache-dir --user -r requirements.txt

COPY --chown=user backend/ ./

# 预下载向量模型（约 166MB）到用户缓存目录，避免首个请求时才下载导致超时
RUN python -c "from chromadb.utils import embedding_functions as ef; ef.ONNXMiniLM_L6_V2()._download_model_if_not_exists()" \
    || echo "模型预下载失败，运行时会自动下载"

# 前端构建产物
COPY --chown=user --from=frontend /build/dist ./static

# 运行时数据目录（知识库为空时会自动重建，无需持久化）
RUN mkdir -p $HOME/app/data/chroma

# 部署环境默认值：无 Redis（走内存降级）
ENV REDIS_URL="" \
    CHROMA_PERSIST_DIRECTORY=/home/user/app/data/chroma \
    EVAL_BASELINE_PATH=/home/user/app/data/eval/baseline.json \
    FRONTEND_DIST=/home/user/app/static \
    PROMETHEUS_PORT=0 \
    CHAT_RATE_LIMIT="20/hour" \
    API_HOST=0.0.0.0 \
    API_PORT=7860

# HF Spaces 约定端口 7860
EXPOSE 7860

CMD ["python", "api/main.py"]
