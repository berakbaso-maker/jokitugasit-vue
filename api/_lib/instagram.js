import crypto from 'node:crypto'
import { createClient } from '@supabase/supabase-js'

const GRAPH_VERSION = process.env.IG_GRAPH_VERSION || 'v23.0'

export function serverSupabase() {
  const url = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) throw new Error('SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY wajib dikonfigurasi')
  return createClient(url, key, { auth: { persistSession: false } })
}

export function allowCors(req, res, methods = 'POST, OPTIONS') {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', methods)
  res.setHeader('Access-Control-Allow-Headers', 'Authorization, Content-Type')
  if (req.method === 'OPTIONS') {
    res.status(204).end()
    return true
  }
  return false
}

export function requireAutomationSecret(req, res) {
  const expected = process.env.IG_AUTOMATION_SECRET
  const supplied = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '')
  if (!expected || !safeEqual(supplied, expected)) {
    res.status(401).json({ error: 'Unauthorized' })
    return false
  }
  return true
}

export function verifyMetaSignature(rawBody, signature) {
  const secret = process.env.IG_APP_SECRET
  if (!secret || !signature?.startsWith('sha256=')) return false
  const digest = `sha256=${crypto.createHmac('sha256', secret).update(rawBody).digest('hex')}`
  return safeEqual(signature, digest)
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left))
  const b = Buffer.from(String(right))
  return a.length === b.length && crypto.timingSafeEqual(a, b)
}

export async function rawRequestBody(req) {
  if (Buffer.isBuffer(req.body)) return req.body
  if (typeof req.body === 'string') return Buffer.from(req.body)
  const chunks = []
  for await (const chunk of req) chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk))
  return Buffer.concat(chunks)
}

export async function graphRequest(path, { method = 'GET', params = {}, token } = {}) {
  const accessToken = token || process.env.IG_ACCESS_TOKEN
  if (!accessToken) throw new Error('IG_ACCESS_TOKEN belum dikonfigurasi')

  const url = new URL(`https://graph.facebook.com/${GRAPH_VERSION}/${path.replace(/^\//, '')}`)
  const body = new URLSearchParams({ ...params, access_token: accessToken })
  const options = { method }

  if (method === 'GET') {
    for (const [key, value] of body) url.searchParams.set(key, value)
  } else {
    options.headers = { 'Content-Type': 'application/x-www-form-urlencoded' }
    options.body = body
  }

  const response = await fetch(url, options)
  const data = await response.json().catch(() => ({}))
  if (!response.ok || data.error) {
    const message = data.error?.message || `Graph API error ${response.status}`
    const error = new Error(message)
    error.status = response.status
    error.details = data.error
    throw error
  }
  return data
}

export async function waitForMediaContainer(containerId, attempts = 10) {
  for (let attempt = 0; attempt < attempts; attempt += 1) {
    const container = await graphRequest(containerId, { params: { fields: 'status_code,status' } })
    if (container.status_code === 'FINISHED') return container
    if (['ERROR', 'EXPIRED'].includes(container.status_code)) {
      throw new Error(container.status || `Media container ${container.status_code}`)
    }
    await new Promise((resolve) => setTimeout(resolve, 3000))
  }
  throw new Error('Media container belum siap dipublikasi; coba lagi beberapa saat')
}

export async function notifyTelegram(message) {
  const token = process.env.TELEGRAM_BOT_TOKEN
  const chatId = process.env.TELEGRAM_NOTIFICATION_CHAT_ID
  if (!token || !chatId) return { skipped: true }

  const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text: message, disable_web_page_preview: true }),
  })
  const data = await response.json().catch(() => ({}))
  if (!response.ok || !data.ok) throw new Error(data.description || 'Gagal mengirim notifikasi Telegram')
  return data
}

export function extractInstagramEvents(payload) {
  const events = []
  for (const entry of payload?.entry || []) {
    for (const change of entry.changes || []) {
      const value = change.value || {}
      events.push({
        eventType: change.field || 'unknown',
        externalId: value.id || value.comment_id || value.media_id || null,
        senderId: value.from?.id || value.sender_id || null,
        username: value.from?.username || value.username || null,
        message: value.text || value.message || value.comment_text || null,
        mediaId: value.media?.id || value.media_id || null,
        commentId: value.comment_id || (change.field === 'comments' ? value.id : null),
        occurredAt: entry.time ? new Date(entry.time * 1000).toISOString() : new Date().toISOString(),
        raw: { entryId: entry.id, field: change.field, value },
      })
    }
    for (const messaging of entry.messaging || []) {
      events.push({
        eventType: 'messages',
        externalId: messaging.message?.mid || null,
        senderId: messaging.sender?.id || null,
        username: null,
        message: messaging.message?.text || null,
        mediaId: null,
        commentId: null,
        occurredAt: messaging.timestamp ? new Date(messaging.timestamp).toISOString() : new Date().toISOString(),
        raw: messaging,
      })
    }
  }
  return events
}
