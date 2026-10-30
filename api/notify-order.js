// Vercel Serverless Function: notifikasi order baru ke Telegram engineer.
// POST /api/notify-order  body: { orderNo }
//
// Keamanan (31 Okt 2026):
//   - Body HANYA berisi orderNo. Isi pesan diambil dari database, jadi tidak
//     bisa dipakai mengirim teks/link palsu ke chat engineer.
//   - Order harus ada, berumur < 30 menit, dan belum pernah diklaim
//     (claim_order_notification = UPDATE atomik) → tidak bisa di-spam.
//   - Klaim butuh service_role; browser tidak bisa memanggil fungsi itu.
import { createClient } from '@supabase/supabase-js'
import { ambilOrderNo, esc, izinkanOrigin, urlAman } from './_lib/http.js'

const CATEGORY_MAP = {
  web: 'Website / Web App', mobile: 'Aplikasi Mobile', desktop: 'Aplikasi Desktop',
  database: 'Database & API', ai: 'AI / Data Science', debug: 'Debug / Fix Error',
  skripsi: 'Skripsi / Final Project', tugas_kuliah: 'Tugas Kuliah Dasar',
  design: 'Desain UI/UX', lainnya: 'Lainnya',
}
const DEADLINE_MAP = { hari_ini: '🔥 HARI INI (Mendesak)', besok: '⚡ Besok (Normal)' }

function serverSupabase() {
  const url = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) return null
  return createClient(url, key, { auth: { persistSession: false } })
}

export default async function handler(req, res) {
  if (izinkanOrigin(req, res)) return
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })

  const orderNo = ambilOrderNo(req.body)
  if (!orderNo) return res.status(400).json({ error: 'orderNo tidak valid' })

  const supabase = serverSupabase()
  if (!supabase) {
    console.error('notify-order: SUPABASE_SERVICE_ROLE_KEY belum diset')
    return res.status(503).json({ error: 'Notifikasi belum dikonfigurasi' })
  }

  const { data, error } = await supabase.rpc('claim_order_notification', { p_order_no: orderNo })
  if (error) {
    console.error('notify-order claim:', error)
    return res.status(500).json({ error: 'Gagal memproses notifikasi' })
  }
  if (!data || data.length === 0) {
    // Sudah dikirim, kedaluwarsa, atau order tidak ada — semuanya tidak
    // mengirim apa pun. Balasan disamakan supaya tidak bisa dipakai
    // menebak nomor order yang valid.
    return res.status(409).json({ ok: false, alasan: 'tidak_diproses' })
  }

  const o = data[0]
  const botToken = process.env.TELEGRAM_BOT_TOKEN
  const chatId = process.env.TELEGRAM_NOTIFICATION_CHAT_ID
  if (!botToken || !chatId) {
    await supabase.rpc('release_order_claim', { p_order_no: orderNo, p_kind: 'telegram' })
    return res.status(503).json({ error: 'Telegram belum dikonfigurasi' })
  }

  const wa = String(o.whatsapp || '').replace(/[^0-9]/g, '')
  const waPenuh = wa.startsWith('62') ? wa : wa.startsWith('0') ? '62' + wa.slice(1) : '62' + wa
  const waUrl = `https://wa.me/${waPenuh}?text=${encodeURIComponent(`Halo ${o.customer_name}, saya engineer jokitugasit.my.id soal request ${o.order_no}.`)}`
  const trackUrl = `${process.env.APP_URL || 'https://jokitugasit.my.id'}/track/${encodeURIComponent(o.order_no)}`
  const deadline = DEADLINE_MAP[o.deadline] || (o.deadline_date ? `📅 ${o.deadline_date}` : '🗓️ Fleksibel')

  let teks = `🔔 <b>ORDER TUGAS BARU MASUK!</b> [<code>#${esc(o.order_no)}</code>]\n`
  teks += '━━━━━━━━━━━━━━━━━━━━━━\n'
  teks += `👤 <b>Mahasiswa</b> : ${esc(o.customer_name)}\n`
  teks += `📱 <b>WhatsApp</b>  : <a href="${waUrl}">+${waPenuh} (Klik untuk Chat)</a>\n`
  teks += `📚 <b>Kategori</b>  : ${esc(CATEGORY_MAP[o.category] || o.category)}\n`
  teks += `⏰ <b>Deadline</b>  : ${esc(deadline)}\n\n`
  teks += `📝 <b>Masalah / Deskripsi:</b>\n<i>${esc(String(o.description || '').slice(0, 1500))}</i>\n`

  const link = urlAman(o.link)
  if (link) teks += `\n🔗 <b>Lampiran Link:</b> <a href="${link}">${link}</a>`
  const file = urlAman(o.file_url)
  if (file) teks += `\n📁 <b>File Upload:</b> <a href="${file}">Unduh Lampiran</a>`

  teks += `\n━━━━━━━━━━━━━━━━━━━━━━\n🔍 <a href="${trackUrl}">Halaman Status Request</a>`

  try {
    const kirim = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ chat_id: chatId, text: teks, parse_mode: 'HTML', disable_web_page_preview: true }),
    })
    const hasil = await kirim.json().catch(() => ({}))
    if (!kirim.ok || !hasil.ok) {
      console.error('Telegram API error:', hasil.description)
      await supabase.rpc('release_order_claim', { p_order_no: orderNo, p_kind: 'telegram' })
      return res.status(502).json({ error: 'Gagal mengirim notifikasi' })
    }
    return res.status(200).json({ ok: true, messageId: hasil.result?.message_id })
  } catch (err) {
    console.error('notify-order:', err)
    await supabase.rpc('release_order_claim', { p_order_no: orderNo, p_kind: 'telegram' })
    return res.status(502).json({ error: 'Gagal mengirim notifikasi' })
  }
}
