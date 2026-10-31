// Uji handler /api/notify-status dengan DB + Resend nyata (tanpa deploy).
import fs from 'node:fs'
import path from 'node:path'
import { createClient } from '@supabase/supabase-js'
import handler from '../api/notify-status.js'

const env = {}
for (const baris of fs.readFileSync(path.join(process.cwd(), '.env'), 'utf8').split('\n')) {
  if (!baris.includes('=') || baris.trim().startsWith('#')) continue
  const i = baris.indexOf('=')
  env[baris.slice(0, i).trim()] = baris.slice(i + 1).trim()
}
const SEKRET = path.join(process.env.HOME, '.hermes/secrets')
process.env.SUPABASE_URL = env.VITE_SUPABASE_URL
process.env.SUPABASE_SERVICE_ROLE_KEY = fs.readFileSync(path.join(SEKRET, 'jokitugasit-service-role.txt'), 'utf8').trim()
process.env.RESEND_API_KEY = fs.readFileSync(path.join(SEKRET, 'jokitugasit-resend.txt'), 'utf8').trim()
process.env.RESEND_FROM = 'JokiTugasIT <noreply@jokitugasit.my.id>'
process.env.APP_URL = 'https://jokitugasit.my.id'

const anon = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_ANON_KEY)
const admin = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } })
const email = process.argv[2] || 'delivered@resend.dev'

function resPalsu() {
  return {
    headers: {}, statusCode: null, body: null,
    setHeader(k, v) { this.headers[k] = v },
    status(c) { this.statusCode = c; return this },
    json(b) { this.body = b; return this },
    end() { return this },
  }
}

const orderNo = await anon.rpc('create_public_request', {
  p_customer_name: 'Uji Kabar Status',
  p_whatsapp: '6281200077777',
  p_description: 'Uji email perubahan status.',
  p_category: 'web',
  p_deadline: 'besok',
  p_email: email,
}).then((r) => { if (r.error) throw r.error; return r.data })
console.log('order dibuat:', orderNo, '| email:', email)

await admin.from('requests').update({ status: 'working' }).eq('order_no', orderNo)

const r1 = resPalsu()
await handler({ method: 'POST', headers: {}, body: { orderNo, status: 'working' } }, r1)
console.log('kabar #1 (working)   :', r1.statusCode, JSON.stringify(r1.body))

const r2 = resPalsu()
await handler({ method: 'POST', headers: {}, body: { orderNo, status: 'working' } }, r2)
console.log('kabar #2 (dobel)     :', r2.statusCode, JSON.stringify(r2.body))

const r3 = resPalsu()
await handler({ method: 'POST', headers: {}, body: { orderNo, status: 'done' } }, r3)
console.log('kabar #3 (salah status):', r3.statusCode, JSON.stringify(r3.body))

const r4 = resPalsu()
await handler({ method: 'POST', headers: {}, body: { orderNo, status: 'lunas' } }, r4)
console.log('kabar #4 (status ilegal):', r4.statusCode, JSON.stringify(r4.body))

const { data: req } = await admin.from('requests').select('status, status_notified').eq('order_no', orderNo).single()
const { data: log } = await admin.from('request_status_notifications').select('status, provider_id').eq('order_no', orderNo)
console.log('DB status_notified   :', JSON.stringify(req))
console.log('log audit            :', JSON.stringify(log))
console.log('order untuk dibersihkan:', orderNo)
if (log?.[0]?.provider_id) {
  const cek = await fetch(`https://api.resend.com/emails/${log[0].provider_id}`, {
    headers: { Authorization: `Bearer ${process.env.RESEND_API_KEY}` },
  })
  const d = await cek.json().catch(() => ({}))
  console.log('resend status        :', cek.status, '|', d.last_event || d.message || '')
  console.log('resend subject       :', d.subject || '')
  console.log('resend to            :', JSON.stringify(d.to || []))
}
