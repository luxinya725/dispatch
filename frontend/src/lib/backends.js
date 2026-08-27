// 本项目只包含 Python(FastAPI) 后端，不再提供 Java 分支。
const DEFAULT_BACKENDS = {
  python: {
    id: 'python',
    label: '后端服务',
    // 开发时走 Vite 代理；生产构建由后端一起托管，直接打同源根路径。
    baseUrl: import.meta.env.VITE_PYTHON_API_URL ?? (import.meta.env.DEV ? '/api/python' : ''),
    port: '8000'
  }
}

export function createInitialSettings() {
  const saved = readSettings()
  return {
    // 固定为 python：忽略历史 localStorage 里可能残留的 'java'
    backend: 'python',
    userId: saved.userId || 'u1001',
    conversationId: saved.conversationId || '',
    endpoints: {
      python: saved.endpoints?.python || DEFAULT_BACKENDS.python.baseUrl
    }
  }
}

export function saveSettings(settings) {
  localStorage.setItem('echomind.frontend.settings', JSON.stringify(settings))
}

export function backendMeta(type, settings) {
  const meta = DEFAULT_BACKENDS[type] || DEFAULT_BACKENDS.python
  return {
    ...meta,
    baseUrl: normalizeBaseUrl(settings.endpoints?.[meta.id] || meta.baseUrl)
  }
}

export async function requestHealth(type, settings) {
  return requestJson(backendMeta(type, settings).baseUrl, '/health')
}

export async function requestMonitor(type, settings) {
  return requestJson(backendMeta(type, settings).baseUrl, '/monitor')
}

export async function requestKnowledgeStats(type, settings) {
  return requestJson(backendMeta(type, settings).baseUrl, '/knowledge/stats')
}

export async function requestSearch(type, settings, query, topK = 5) {
  const params = new URLSearchParams({ query, topK: String(topK) })
  return requestJson(backendMeta(type, settings).baseUrl, `/search?${params}`, { method: 'POST' })
}

export async function requestChat(type, settings, message) {
  const meta = backendMeta(type, settings)
  const payload = buildChatPayload(type, settings, message)
  const raw = await requestJson(meta.baseUrl, '/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
  })
  return normalizeChatResponse(type, raw)
}

export async function addKnowledge(type, settings, documents) {
  return requestJson(backendMeta(type, settings).baseUrl, '/knowledge/add', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ documents })
  })
}

export async function uploadKnowledge(type, settings, file) {
  const form = new FormData()
  form.append('file', file)
  return requestJson(backendMeta(type, settings).baseUrl, '/knowledge/upload', {
    method: 'POST',
    body: form
  })
}

function buildChatPayload(type, settings, message) {
  if (type === 'python') {
    return {
      message,
      user_id: settings.userId || 'anonymous',
      conv_id: settings.conversationId || undefined
    }
  }
  return {
    message,
    user_id: settings.userId || 'anonymous',
    conversation_id: settings.conversationId || undefined
  }
}

function normalizeChatResponse(type, raw) {
  return {
    backend: type,
    conversationId: raw.conversation_id || raw.conversationId || raw.conv_id || '',
    response: raw.response || '',
    intent: raw.intent || 'other',
    intentGroup: raw.intent_group || raw.intentGroup || 'other',
    intentConfidence: Number(raw.intent_confidence ?? raw.intentConfidence ?? 0),
    agentType: raw.agent_type || raw.agentType || '',
    primaryAgent: raw.primary_agent || raw.primaryAgent || raw.agent_type || '',
    supportingAgents: raw.supporting_agents || raw.supportingAgents || [],
    agentTypes: raw.agent_types || raw.agentTypes || [],
    routingReason: raw.routing_reason || raw.routingReason || '',
    routingConfidence: Number(raw.routing_confidence ?? raw.routingConfidence ?? 0),
    escalated: Boolean(raw.escalated),
    latencyMs: Number(raw.latency_ms ?? raw.latencyMs ?? 0),
    knowledgeUsed: Boolean(raw.knowledge_used ?? raw.knowledgeUsed),
    entities: raw.entities || {},
    citations: [],
    verified: raw.verified,
    grounded: raw.grounded,
    raw
  }
}

async function requestJson(baseUrl, path, options = {}) {
  const url = `${normalizeBaseUrl(baseUrl)}${path}`
  const response = await fetch(url, options)
  const text = await response.text()
  let data = null
  try {
    data = text ? JSON.parse(text) : null
  } catch {
    data = text
  }
  if (!response.ok) {
    const detail = typeof data === 'string' ? data : JSON.stringify(data)
    throw new Error(`${response.status} ${response.statusText}: ${detail}`)
  }
  return data
}

function normalizeBaseUrl(value) {
  return String(value || '').replace(/\/+$/, '')
}

function readSettings() {
  try {
    return JSON.parse(localStorage.getItem('echomind.frontend.settings') || '{}')
  } catch {
    return {}
  }
}
