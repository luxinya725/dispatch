---
title: Dispatch
emoji: 🎯
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
---

# Dispatch · 多 Agent 客服编排

面向复杂客服场景的多 Agent 编排系统。用户的一条消息会经过意图识别、知识库检索、多 Agent 路由，最终生成带来源引用和路由依据的回答。

## 它解决什么问题

传统人工客服分流有几个固有痛点，这套系统针对性地做了设计：

| 人工流程的问题 | 对应设计 |
|---|---|
| 复合问题（如"登录报错 + 重复扣款"）转给一个人后只答一半 | 主 Agent + 辅助 Agent 并行处理，结果合并 |
| 分流靠人工判断，慢且不稳定 | 三路融合意图识别（LLM + 语义相似度 + 关键词），输出置信度 |
| 业务规则更新后，靠开会同步，总有人用旧规则回答 | Skills 以 Markdown 存放，可热加载，规则与代码解耦 |
| 无关问题也去检索知识库，浪费成本还污染上下文 | 按意图触发 RAG，问候/转人工类请求不检索 |
| 效果好坏只能凭感觉 | Monitor 在线指标 + LLM-as-Judge 四维评测 + 回归检测 |
| 出了问题不知道为什么这么答 | 每条回答返回 `routing_reason`、`routing_confidence` 和引用来源 |

高风险、低置信度的请求会显式转人工，不做自动化处理。

## 核心链路

```
用户消息
  → MemoryManager   读取工作记忆 / 历史摘要 / 用户画像
  → IntentRecognizer 三路融合识别意图与实体
  → KnowledgeBase   按意图触发 RAG：查询改写 → 并行召回 → 合并去重 → LLM 重排
  → AgentOrchestrator 计算领域分数 → 主 Agent + 辅助 Agent
  → LLM 生成回答（注入对应 Skills 规则）
  → 写回记忆，异步更新用户画像
```

## 技术栈

FastAPI · ChromaDB（向量检索）· Redis（工作记忆）· DeepSeek / Anthropic 兼容接口 · Vue 3 + Vite · Prometheus

## 本地运行

```bash
cp backend/.env.example backend/.env   # 填入 API Key
bash start.sh
```

- 前端 http://localhost:5173
- 后端 http://localhost:8000 （Swagger: `/docs`）

依赖说明：
- **Redis** 本机原生运行即可（`brew install redis`）；未配置 `REDIS_URL` 时自动降级为内存模式
- **ChromaDB** 无需单独部署，默认走内嵌模式，数据在 `backend/data/chroma/`
- **知识库** 首次启动自动灌入 6 篇内置客服文档；可通过 `/knowledge/upload` 导入自有文档

## 部署

单容器部署，前端构建产物由 FastAPI 一起托管：

```bash
docker build -t dispatch .
docker run -p 7860:7860 -e ANTHROPIC_API_KEY=your_key dispatch
```

部署到 Hugging Face Spaces 时，在 Settings → Secrets 配置 `ANTHROPIC_API_KEY`，**不要**把 `.env` 提交到仓库。

公开部署默认对 `/chat` 按 IP 限流 20 次/小时，可用 `CHAT_RATE_LIMIT` 调整（设为空关闭）。

## 主要接口

| 方法 | 路径 | 说明 |
|---|---|---|
| POST | `/chat` | 主对话，返回回答 + 路由决策 + 意图 |
| POST | `/search` | 知识库检索（含查询改写与重排） |
| POST | `/knowledge/upload` | 上传 `.txt` / `.md` / `.json` 导入知识库 |
| GET | `/monitor` | Agent 与工具的在线指标 |
| POST | `/eval/run` | 运行端到端评测 |
| GET | `/docs` | Swagger UI |

## 说明

内置知识库为演示用的模拟客服文档，用于验证检索链路本身；接入真实业务文档只需通过上传接口导入，无需改动代码。
