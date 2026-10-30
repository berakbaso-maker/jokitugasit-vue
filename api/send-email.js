// Vercel Serverless Function: kirim email booking via Resend.
// POST /api/send-email  body: { orderNo }
//
// Keamanan (31 Okt 2026):
//   - Body HANYA orderNo. Alamat tujuan & isi email diambil dari DB, jadi
//     endpoint ini tidak bisa dipakai mengirim email sembarang dari domain
//     jokitugasit (spam/phishing).
//   - Sekali pakai per order (claim_order_email) + hanya order < 30 menit.
//   - Semua nilai di-escape sebelum masuk HTML.
import { createClient } from '@supabase/supabase-js'
import { ambilOrderNo, esc, izinkanOrigin } from './_lib/http.js'

const CATEGORY_LABEL = {
  web: 'Website / Web App', mobile: 'Aplikasi Mobile', desktop: 'Aplikasi Desktop',
  database: 'Database & API', ai: 'AI / Data Science', debug: 'Debug / Fix Error',
  skripsi: 'Skripsi / Final Project', tugas_kuliah: 'Tugas Kuliah Dasar',
  design: 'Desain UI/UX', lainnya: 'Lainnya',
}
const DEADLINE_LABEL = { hari_ini: 'Hari ini (mendesak)', besok: 'Besok (normal)' }

function serverSupabase() {
  const url = process.env.SUPABASE_URL || process.env.VITE_SUPABASE_URL
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY
  if (!url || !key) return null
  return createClient(url, key, { auth: { persistSession: false } })
}

function htmlBooking(o) {
  const track = `${process.env.APP_URL || 'https://jokitugasit.my.id'}/track/${encodeURIComponent(o.order_no)}`
  const estimasi = o.quote_amount ? 'Rp ' + Number(o.quote_amount).toLocaleString('id-ID') : 'Akan dikonfirmasi via WhatsApp'
  const deadline = DEADLINE_LABEL[o.deadline] || (o.deadline_date ? String(o.deadline_date) : 'Fleksibel')

  return `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;border:1px solid #e2e8f0;border-radius:16px;overflow:hidden">
    <div style="background:#2563EB;padding:24px;text-align:center">
      <h2 style="color:#fff;margin:0">jokitugasit.my.id</h2>
      <p style="color:#dbeafe;margin:4px 0 0">Project kamu sudah masuk 👌</p>
    </div>
    <div style="padding:24px">
      <p>Halo <b>${esc(o.customer_name)}</b>,</p>
      <p>Terima kasih sudah mempercayakan tugasmu ke kami. Ringkasan request kamu:</p>
      <table style="width:100%;border-collapse:collapse;margin:16px 0">
        <tr><td style="padding:8px;color:#64748b">Kode Booking</td><td style="padding:8px;font-weight:bold">${esc(o.order_no)}</td></tr>
        <tr><td style="padding:8px;color:#64748b">Jenis Tugas</td><td style="padding:8px">${esc(CATEGORY_LABEL[o.category] || o.category)}</td></tr>
        <tr><td style="padding:8px;color:#64748b">Deadline</td><td style="padding:8px">${esc(deadline)}</td></tr>
        <tr><td style="padding:8px;color:#64748b">Estimasi</td><td style="padding:8px">${esc(estimasi)}</td></tr>
      </table>
      <p style="color:#64748b;margin:8px 0"><b>Deskripsi:</b></p>
      <p style="background:#f8fafc;padding:12px;border-radius:8px;color:#334155">${esc(o.description || '-')}</p>
      <a href="${track}" style="display:block;text-align:center;background:#2563EB;color:#fff;padding:14px;border-radius:10px;text-decoration:none;font-weight:bold;margin:20px 0">🔍 Cek Status Request</a>
      <p style="color:#64748b;font-size:14px">Engineer kami akan menghubungimu via WhatsApp untuk diskusi detail &amp; harga.</p>
    </div>
    <div style="background:#f8fafc;padding:16px;text-align:center;color:#94a3b8;font-size:12px">© 2026 jokitugasit.my.id</div>
  </div>`
}

export default async function handler(req, res) {
  if (izinkanOrigin(req, res)) return
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method not allowed' })

  const orderNo = ambilOrderNo(req.body)
  if (!orderNo) return res.status(400).json({ error: 'orderNo tidak valid' })

  const supabase = serverSupabase()
  if (!supabase) {
    console.error('send-email: SUPABASE_SERVICE_ROLE_KEY belum diset')
    return res.status(503).json({ error: 'Email belum dikonfigurasi' })
  }

  const { data, error } = await supabase.rpc('claim_order_email', { p_order_no: orderNo })
  if (error) {
    console.error('send-email claim:', error)
    return res.status(500).json({ error: 'Gagal memproses email' })
  }
  if (!data || data.length === 0) {
    // Tidak ada email / sudah dikirim / order tidak ada.
    return res.status(409).json({ ok: false, alasan: 'tidak_diproses' })
  }

  const apiKey = process.env.RESEND_API_KEY
  const fromEmail = process.env.RESEND_FROM || 'JokiTugasIT <onboarding@resend.dev>'
  if (!apiKey) {
    await supabase.rpc('release_order_claim', { p_order_no: orderNo, p_kind: 'email' })
    return res.status(503).json({ error: 'Resend belum dikonfigurasi' })
  }

  const o = data[0]
  try {
    const kirim = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from: fromEmail,
        to: [o.email],
        subject: `Kode Booking JokiTugasIT - ${o.order_no}`,
        html: htmlBooking(o),
      }),
    })
    if (!kirim.ok) {
      const teks = await kirim.text()
      console.error('Resend error:', kirim.status, teks.slice(0, 300))
      await supabase.rpc('release_order_claim', { p_order_no: orderNo, p_kind: 'email' })
      return res.status(502).json({ error: 'Gagal mengirim email' })
    }
    return res.status(200).json({ ok: true })
  } catch (err) {
    console.error('send-email:', err)
    await supabase.rpc('release_order_claim', { p_order_no: orderNo, p_kind: 'email' })
    return res.status(502).json({ error: 'Gagal mengirim email' })
  }
}
