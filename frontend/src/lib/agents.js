export const AGENT_META = {
  general: { label: '运营协调 Agent', short: 'General', color: '#00a870', bg: '#e8f8f2' },
  technical: { label: '技术可靠性 Agent', short: 'Technical', color: '#7b61ff', bg: '#f2eeff' },
  billing: { label: '收入与合规 Agent', short: 'Billing', color: '#ff9c00', bg: '#fff7e8' },
  escalation: { label: '人工升级通道', short: 'Escalation', color: '#f53f3f', bg: '#ffece8' }
}

export function baseAgentKey(type) {
  return String(type || '').replace(/_\d+$/, '')
}

export function agentMeta(type) {
  const key = baseAgentKey(type)
  return AGENT_META[key] || { label: type || '未知 Agent', short: type || '?', color: '#526174', bg: '#eef2f6' }
}
