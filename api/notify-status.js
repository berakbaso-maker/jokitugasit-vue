// Vercel Serverless Function: kabari klien saat status order berubah.
// POST /api/notify-status  body: { orderNo, status }
//
// Keamanan (sama seperti notify-order/send-email):
//   - Body hanya orderNo + status. Alamat & isi email diambil dari DB, jadi
//     endpoint tidak bisa dipakai mengirim email sembarang dari domain kita.
//   - status harus salah satu nilai resmi (whitelist), bukan teks bebas.
//   - Sekali per transisi status (klaim atomik di DB), anti dobel-klik.
import { createClient } from '@supabase/supabase-js'
import { ambilOrderNo, esc, izinkanOrigin } from './_lib/http.js'
import { STATUS_SAH, htmlStatusUpdate, subjekStatus } from './_lib/status-email.js'

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
  const status = String(req.body?.status || '').trim().toLowerCase()
  if (!orderNo) return res.status(400).json({ error: 'orderNo tidak valid' })
  if (!STATUS_SAH.includes(status)) return res.status(400).json({ error: 'status tidak valid' })

  const supabase = serverSupabase()
  if (!supabase) {
    console.error('notify-status: SUPABASE_SERVICE_ROLE_KEY belum diset')
    return res.status(503).json({ error: 'Notifikasi belum dikonfigurasi' })
  }

  const { data, error } = await supabase.rpc('claim_status_notification', {
    p_order_no: orderNo,
    p_status: status,
  })
  if (error) {
    console.error('notify-status claim:', error)
    return res.status(500).json({ error: 'Gagal memproses notifikasi' })
  }
  if (!data || data.length === 0) {
    // Order tidak ada / status tidak cocok / klien tanpa email / sudah dikabari.
    return res.status(409).json({ ok: false, alasan: 'tidak_diproses' })
  }

  const apiKey = process.env.RESEND_API_KEY
  const fromEmail = process.env.RESEND_FROM || 'JokiTugasIT <noreply@jokitugasit.my.id>'
  if (!apiKey) {
    await supabase.rpc('release_status_notification', { p_order_no: orderNo, p_status: status })
    return res.status(503).json({ error: 'Email belum dikonfigurasi' })
  }

  const o = data[0]
  try {
    const kirim = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: fromEmail,
        to: [o.email],
        subject: subjekStatus(o.order_no, status),
        html: htmlStatusUpdate(o),
      }),
    })
    if (!kirim.ok) {
      const teks = await kirim.text()
      console.error('Resend error (status):', kirim.status, esc(teks).slice(0, 300))
      await supabase.rpc('release_status_notification', { p_order_no: orderNo, p_status: status })
      return res.status(502).json({ error: 'Gagal mengirim email' })
    }
    const hasil = await kirim.json().catch(() => ({}))
    await supabase.from('request_status_notifications').insert({
      order_no: o.order_no,
      status,
      provider_id: hasil?.id || null,
    })
    return res.status(200).json({ ok: true })
  } catch (err) {
    console.error('notify-status:', err)
    await supabase.rpc('release_status_notification', { p_order_no: orderNo, p_status: status })
    return res.status(502).json({ error: 'Gagal mengirim email' })
  }
}
