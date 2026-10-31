// Uji handler /api/notify-order & /api/send-email secara lokal dengan env nyata.
// Dipakai untuk membuktikan klaim sekali pakai + pengiriman sungguhan.
import fs from 'node:fs'
import path from 'node:path'
import { createClient } from '@supabase/supabase-js'
import notifyHandler from '../api/notify-order.js'
import emailHandler from '../api/send-email.js'

const env = {}
for (const baris of fs.readFileSync(path.join(process.cwd(), '.env'), 'utf8').split('\n')) {
  if (!baris.includes('=') || baris.trim().startsWith('#')) continue
  const i = baris.indexOf('=')
  env[baris.slice(0, i).trim()] = baris.slice(i + 1).trim()
}
const SEKRET = path.join(process.env.HOME, '.hermes/secrets')
process.env.SUPABASE_URL = env.VITE_SUPABASE_URL
process.env.SUPABASE_SERVICE_ROLE_KEY = fs.readFileSync(path.join(SEKRET, 'jokitugasit-service-role.txt'), 'utf8').trim()
process.env.TELEGRAM_BOT_TOKEN = env.TELEGRAM_BOT_TOKEN
process.env.TELEGRAM_NOTIFICATION_CHAT_ID = env.TELEGRAM_NOTIFICATION_CHAT_ID
process.env.RESEND_API_KEY = fs.existsSync(path.join(SEKRET, 'jokitugasit-resend.txt'))
  ? fs.readFileSync(path.join(SEKRET, 'jokitugasit-resend.txt'), 'utf8').trim()
  : env.RESEND_API_KEY
if (env.RESEND_FROM) process.env.RESEND_FROM = env.RESEND_FROM
process.env.APP_URL = 'https://jokitugasit.my.id'
if (!process.env.RESEND_FROM) process.env.RESEND_FROM = 'JokiTugasIT <noreply@jokitugasit.my.id>'

const anon = createClient(env.VITE_SUPABASE_URL, env.VITE_SUPABASE_ANON_KEY)
const admin = createClient(env.VITE_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { persistSession: false } })

function resPalsu() {
  return {
    headers: {}, statusCode: null, body: null,
    setHeader(k, v) { this.headers[k] = v },
    status(c) { this.statusCode = c; return this },
    json(b) { this.body = b; return this },
    end() { return this },
  }
}

const email = process.argv[2] || null
const orderNo = await anon.rpc('create_public_request', {
  p_customer_name: 'Uji Notifikasi',
  p_whatsapp: '6281200012345',
  p_description: 'Uji pengiriman notifikasi dari handler baru.',
  p_category: 'web',
  p_deadline: 'besok',
  p_referral_code: null,
  ...(email ? { p_email: email } : {}),
}).then((r) => { if (r.error) throw r.error; return r.data })

console.log('order dibuat:', orderNo, email ? `(email: ${email})` : '(tanpa email)')

const r1 = resPalsu()
await notifyHandler({ method: 'POST', headers: {}, body: { orderNo } }, r1)
console.log('notify #1:', r1.statusCode, JSON.stringify(r1.body))

const r2 = resPalsu()
await notifyHandler({ method: 'POST', headers: {}, body: { orderNo } }, r2)
console.log('notify #2 (harus 409):', r2.statusCode, JSON.stringify(r2.body))

const r3 = resPalsu()
await emailHandler({ method: 'POST', headers: {}, body: { orderNo } }, r3)
console.log('email  #1:', r3.statusCode, JSON.stringify(r3.body))

const r4 = resPalsu()
await emailHandler({ method: 'POST', headers: {}, body: { orderNo } }, r4)
console.log('email  #2 (harus 409):', r4.statusCode, JSON.stringify(r4.body))

const { data } = await admin.from('requests').select('order_no, notified_at, email_sent_at').eq('order_no', orderNo).single()
console.log('status klaim di DB:', JSON.stringify(data))
console.log('order untuk dibersihkan:', orderNo)
