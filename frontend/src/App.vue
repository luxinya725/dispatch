<template>
  <main class="app-shell">
    <aside class="sidebar">
     <div class="sidebar-inner">
      <section class="brand">
        <div class="brand-mark">D</div>
        <div>
          <h1>Dispatch</h1>
          <p>企业智能运营调度台 · 多 Agent 客服编排</p>
        </div>
      </section>

      <p class="group-label">开始体验</p>
      <section class="panel scenario-panel">
        <div class="panel-heading">
          <h2>场景速览</h2>
          <span class="pill soft">一键体验</span>
        </div>
        <p class="scenario-hint">点击场景自动发送示例问题，直观展示意图识别、主辅 Agent 路由与知识库引用。</p>
        <div class="scenario-buttons">
          <button
            v-for="s in DEMO_SCENARIOS"
            :key="s.id"
            type="button"
            class="scenario-button"
            :disabled="busy"
            @click="runScenario(s)"
          >{{ s.label }}</button>
        </div>
      </section>

      <p class="group-label">系统表现</p>
      <section class="panel insight-panel">
        <div class="panel-heading">
          <h2>运行洞察</h2>
          <span class="pill soft">实时数据</span>
        </div>
        <p class="panel-subnote">随对话实时更新</p>
        <div v-if="agentStatsEntries.length" class="agent-stats">
          <div
            v-for="[key, stat] in agentStatsEntries"
            :key="key"
            :class="['agent-stat-row', { active: isAgentActive(key) }]"
            :style="{ '--agent-bg': agentMeta(key).bg }"
          >
            <span class="agent-name" :style="{ color: agentMeta(key).color }">{{ agentMeta(key).label }}</span>
            <div class="mini-bar"><div class="mini-fill" :style="{ width: Math.round((stat.success_rate || 0) * 100) + '%', background: agentMeta(key).color }"></div></div>
            <span :class="['stat-num', { flash: isAgentActive(key) }]">{{ Math.round((stat.success_rate || 0) * 100) }}% · {{ agentLatency(key, stat) }}ms</span>
          </div>
        </div>
        <p v-else class="scenario-hint">暂无监控数据，点击下方「刷新状态」获取。</p>

        <div v-if="routingLog.length" class="routing-log">
          <h3>最近路由决策</h3>
          <div v-for="log in routingLog" :key="log.id" class="log-item">
            <span class="log-time">{{ log.time }}</span>
            <span class="log-route">
              <span :style="{ color: agentMeta(log.primaryAgent).color }">{{ agentMeta(log.primaryAgent).label }}</span>
              <template v-if="log.supportingAgents.length">
                + {{ log.supportingAgents.map((a) => agentMeta(a).label).join('、') }}
              </template>
            </span>
            <span class="log-conf">{{ Math.round(log.routingConfidence * 100) }}%</span>
          </div>
        </div>

      </section>
     </div>
    </aside>

    <section class="workspace">
      <header class="workspace-header">
        <div>
          <span class="eyebrow">Dispatch Workspace</span>
          <h2>多 Agent 客服协同 Demo</h2>
          <p>{{ currentBackend.baseUrl }}</p>
        </div>
      </header>

      <div v-if="connectionError" class="connection-banner">
        <div>
          <strong>无法连接到后端服务</strong>
          <p>{{ connectionError }}</p>
        </div>
        <button type="button" @click="checkHealth">重试</button>
      </div>

      <section class="chat-panel">
        <div class="persona-banner">👤 客户视角模拟 — 您现在扮演的是终端客户，输入问题体验 AI 客服的真实应答效果</div>
        <div class="messages" ref="messageList">
          <article v-for="item in messages" :key="item.id" :id="`msg-${item.id}`" :class="['message', item.role]">
            <template v-if="item.role === 'user'">
              <div class="message-meta"><span>用户</span></div>
              <p class="message-text">{{ item.content }}</p>
            </template>

            <template v-else-if="item.role === 'error'">
              <div class="message-meta"><span>请求失败</span></div>
              <p class="message-text">{{ item.content }}</p>
            </template>

            <template v-else>
              <div class="agent-row">
                <span class="agent-badge" :style="badgeStyle(item.data.primaryAgent)">{{ agentMeta(item.data.primaryAgent).label }} · 主处理</span>
                <span v-for="a in item.data.supportingAgents" :key="a" class="agent-badge supporting" :style="badgeStyle(a)">{{ agentMeta(a).label }} · 协同</span>
                <span v-if="item.data.escalated" class="agent-badge escalation-flag">已转人工</span>
                <span v-if="item.data.verified" class="agent-badge muted-flag">已核验</span>
              </div>

              <p class="message-text">{{ item.content }}</p>

              <div class="routing-strip">
                <div class="confidence">
                  <span>路由置信度</span>
                  <div class="bar"><div class="fill" :style="{ width: Math.round(item.data.routingConfidence * 100) + '%' }"></div></div>
                  <strong>{{ Math.round(item.data.routingConfidence * 100) }}%</strong>
                </div>
                <p class="routing-reason">路由依据：{{ item.data.routingReason || '—' }}</p>
              </div>

              <div v-if="item.data.citations && item.data.citations.length" class="citation-bar">
                <span class="citation-label">引用来源</span>
                <button
                  v-for="(c, idx) in item.data.citations"
                  :key="idx"
                  type="button"
                  class="citation-chip"
                  :class="{ active: isCitationOpen(item.id, idx) }"
                  @click="showCitation(item, idx)"
                >{{ c.title || '未命名文档' }}</button>
              </div>

              <div class="message-footer">
                <span>意图 {{ item.data.intentGroup }}/{{ item.data.intent }}</span>
                <span>延迟 {{ Math.round(item.data.latencyMs) }}ms</span>
              </div>
            </template>
          </article>

          <div v-if="messages.length === 0" class="empty-state">
            <h3>开始一次客服对话</h3>
            <p>试着输入一个复合问题，例如"登录一直报401，而且这个月还重复扣款了"，观察系统如何做主辅 Agent 协同。</p>
          </div>
        </div>

        <form class="composer" @submit.prevent="sendMessage">
          <textarea v-model="draft" rows="3" placeholder="输入问题，例如：我想申请退款，订单号是 #12345"></textarea>
          <button :disabled="busy || !draft.trim()">{{ busy ? '发送中' : '发送' }}</button>
        </form>
      </section>

      <section class="tools-grid">
        <article class="tool-panel" ref="knowledgePanel">
          <div class="panel-heading">
            <h2>知识库引用体验</h2>
            <span class="pill soft">RAG</span>
          </div>
          <p class="scenario-hint">AI 的每条回答都基于知识库检索生成，您可以在这里单独体验检索效果</p>

          <div v-if="citationView" class="citation-context">
            <span>以下是刚才那条回答引用的知识来源</span>
            <a href="#" @click.prevent="backToConversation">返回对话</a>
          </div>

          <div class="inline-form">
            <input v-model="searchQuery" placeholder="输入一个问题，查看系统会引用哪些知识文档" />
            <button type="button" @click="searchKnowledge" :disabled="busy || !searchQuery.trim()">检索</button>
          </div>
          <div class="result-list">
            <article v-for="(item, idx) in panelResults" :key="item.id || item.title || idx" class="result-item">
              <strong>{{ item.title || '未命名结果' }}</strong>
              <span>score {{ item.score ?? '-' }}</span>
              <p>{{ item.content }}</p>
            </article>
          </div>
        </article>

        <article class="tool-panel">
          <div class="panel-heading">
            <h2>导入知识</h2>
            <span class="pill soft">Docs</span>
          </div>
          <label>
            <span>标题</span>
            <input v-model="docTitle" placeholder="退款补充政策" />
          </label>
          <label>
            <span>内容</span>
            <textarea v-model="docContent" rows="5" placeholder="输入知识库内容"></textarea>
          </label>
          <div class="actions">
            <button type="button" @click="submitKnowledge" :disabled="busy || !docTitle.trim() || !docContent.trim()">添加文档</button>
            <label class="file-button">
              上传文件
              <input type="file" accept=".txt,.md,.json" @change="handleUpload" />
            </label>
          </div>
          <p v-if="toolsNote" class="scenario-hint">{{ toolsNote }}</p>
        </article>
      </section>
    </section>
  </main>

  <footer class="app-footer">
    <p>本系统以 API 形式交付，可嵌入企业自有应用 · <a :href="docsUrl" target="_blank" rel="noreferrer">API 文档</a></p>
  </footer>
</template>

<script setup>
import { computed, nextTick, onMounted, reactive, ref } from 'vue'
import {
  addKnowledge,
  backendMeta,
  createInitialSettings,
  requestChat,
  requestHealth,
  requestKnowledgeStats,
  requestMonitor,
  requestSearch,
  saveSettings,
  uploadKnowledge
} from './lib/backends'
import { agentMeta, baseAgentKey } from './lib/agents'
import { DEMO_SCENARIOS } from './lib/scenarios'

const settings = reactive(createInitialSettings())
const messages = ref([])
const draft = ref('')
const busy = ref(false)
const healthOk = ref(false)
const healthLabel = ref('未检查')
const connectionError = ref('')
const knowledgeCount = ref('-')
const monitorStats = ref(null)
const routingLog = ref([])
const searchQuery = ref('退款多久能到账')
const searchResults = ref([])
const docTitle = ref('退款补充政策')
const docContent = ref('大促期间退款审核时间可能延长到 3-5 个工作日。')
const toolsNote = ref('')
const messageList = ref(null)
const activeAgents = ref([])
const turnLatency = ref({})
let highlightTimer = null
const knowledgePanel = ref(null)
const citationView = ref(null)

const currentBackend = computed(() => backendMeta(settings.backend, settings))
const docsUrl = computed(() => `${currentBackend.value.baseUrl}/docs`)
const agentStatsEntries = computed(() => Object.entries(monitorStats.value?.agent_stats || {}))
const panelResults = computed(() => citationView.value?.items ?? searchResults.value)

onMounted(() => {
  checkHealth()
  loadStats()
})

function badgeStyle(type) {
  const meta = agentMeta(type)
  return { color: meta.color, background: meta.bg }
}

function isAgentActive(statKey) {
  return activeAgents.value.includes(baseAgentKey(statKey))
}

function agentLatency(statKey, stat) {
  const live = turnLatency.value[baseAgentKey(statKey)]
  return Math.round(live ?? stat.avg_ms ?? stat.avg_latency_ms ?? 0)
}

function isCitationOpen(messageId, idx) {
  return citationView.value?.messageId === messageId && citationView.value?.index === idx
}

async function showCitation(message, idx) {
  const citation = message.data.citations[idx]
  if (!citation) return

  citationView.value = { messageId: message.id, index: idx, items: [citation] }
  await nextTick()
  knowledgePanel.value?.scrollIntoView({ behavior: 'smooth', block: 'center' })
}

function backToConversation() {
  const target = citationView.value?.messageId
  citationView.value = null
  if (target) {
    document.getElementById(`msg-${target}`)?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  }
}

function flashAgents(agentTypes, latencyMs) {
  const keys = [...new Set((agentTypes || []).map(baseAgentKey).filter(Boolean))]
  if (!keys.length) return

  turnLatency.value = { ...turnLatency.value, ...Object.fromEntries(keys.map((k) => [k, latencyMs])) }
  activeAgents.value = keys

  clearTimeout(highlightTimer)
  highlightTimer = setTimeout(() => { activeAgents.value = [] }, 1500)
}

function persist() {
  saveSettings(settings)
}

function runScenario(scenario) {
  draft.value = scenario.message
  sendMessage()
}

async function sendMessage() {
  const content = draft.value.trim()
  if (!content) return
  messages.value.push({ id: crypto.randomUUID(), role: 'user', content })
  draft.value = ''
  busy.value = true
  try {
    const response = await requestChat(settings.backend, settings, content)

    if (response.conversationId && !settings.conversationId) {
      settings.conversationId = response.conversationId
      persist()
    }

    let citations = response.citations || []
    if (response.knowledgeUsed && citations.length === 0) {
      try {
        const searchData = await requestSearch(settings.backend, settings, content, 3)
        citations = (searchData.results || []).map((r) => ({ title: r.title, content: r.content, score: r.score }))
      } catch {
        // best-effort enrichment only, ignore failures
      }
    }

    const data = { ...response, citations }
    messages.value.push({ id: crypto.randomUUID(), role: 'assistant', content: response.response, data })
    routingLog.value = [
      {
        id: crypto.randomUUID(),
        time: new Date().toLocaleTimeString('zh-CN', { hour12: false }),
        primaryAgent: data.primaryAgent,
        supportingAgents: data.supportingAgents,
        routingConfidence: data.routingConfidence
      },
      ...routingLog.value
    ].slice(0, 5)
    flashAgents(data.agentTypes?.length ? data.agentTypes : [data.primaryAgent, ...data.supportingAgents], data.latencyMs)
  } catch (error) {
    messages.value.push({ id: crypto.randomUUID(), role: 'error', content: error.message })
  } finally {
    busy.value = false
    await nextTick()
    messageList.value?.scrollTo({ top: messageList.value.scrollHeight, behavior: 'smooth' })
  }
}

async function checkHealth() {
  connectionError.value = ''
  try {
    const data = await requestHealth(settings.backend, settings)
    healthOk.value = data.status === 'ok'
    healthLabel.value = data.status || 'ok'
  } catch (error) {
    healthOk.value = false
    healthLabel.value = '不可用'
    connectionError.value = error.message
  }
}

async function loadStats() {
  try {
    const [stats, monitor] = await Promise.allSettled([
      requestKnowledgeStats(settings.backend, settings),
      requestMonitor(settings.backend, settings)
    ])
    if (stats.status === 'fulfilled') {
      knowledgeCount.value = stats.value.total_chunks ?? stats.value.totalChunks ?? '-'
    }
    if (monitor.status === 'fulfilled') {
      monitorStats.value = monitor.value
    }
  } catch {
    // status panel is best-effort; chat flow surfaces real errors
  }
}

async function searchKnowledge() {
  busy.value = true
  citationView.value = null
  try {
    const data = await requestSearch(settings.backend, settings, searchQuery.value, 5)
    searchResults.value = data.results || []
  } catch (error) {
    toolsNote.value = error.message
  } finally {
    busy.value = false
  }
}

async function submitKnowledge() {
  busy.value = true
  toolsNote.value = ''
  try {
    await addKnowledge(settings.backend, settings, [
      { title: docTitle.value.trim(), content: docContent.value.trim() }
    ])
    toolsNote.value = '文档已添加'
    await loadStats()
  } catch (error) {
    toolsNote.value = error.message
  } finally {
    busy.value = false
  }
}

async function handleUpload(event) {
  const file = event.target.files?.[0]
  event.target.value = ''
  if (!file) return
  busy.value = true
  toolsNote.value = ''
  try {
    await uploadKnowledge(settings.backend, settings, file)
    toolsNote.value = `已上传 ${file.name}`
    await loadStats()
  } catch (error) {
    toolsNote.value = error.message
  } finally {
    busy.value = false
  }
}
</script>
