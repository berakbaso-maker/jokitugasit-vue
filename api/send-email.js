// Vercel Serverless Function: kirim email booking via Resend
// Endpoint: POST /api/send-email
// Resend gratis: 3.000 email/bulan, tanpa SMTP ribet

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  if (req.method === 'OPTIONS') return res.status(204).end()

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  const { email, orderNo, customerName, category, deadline, description, quoteAmount } = req.body || {}

  if (!email || !orderNo || !customerName) {
    return res.status(400).json({ error: 'email, orderNo, customerName wajib diisi' })
  }

  const apiKey = process.env.RESEND_API_KEY
  const fromEmail = process.env.RESEND_FROM || 'JokiTugasIT <onboarding@resend.dev>'

  if (!apiKey) {
    return res.status(500).json({ error: 'RESEND_API_KEY belum dikonfigurasi' })
  }

  const trackUrl = `https://jokitugasit-vue.vercel.app/track/${orderNo}`
  const rupiah = quoteAmount ? 'Rp ' + Number(quoteAmount).toLocaleString('id-ID') : 'Belum ditentukan'

  const html = `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;border:1px solid #e2e8f0;border-radius:16px;overflow:hidden">
    <div style="background:#2563EB;padding:24px;text-align:center">
      <h2 style="color:#fff;margin:0">JokiTugasIT.id</h2>
      <p style="color:#dbeafe;margin:4px 0 0">Project kamu sudah masuk 👌</p>
    </div>
    <div style="padding:24px">
      <p>Halo <b>${customerName}</b>,</p>
      <p>Terima kasih sudah mempercayakan tugasmu ke kami! Berikut ringkasan request kamu:</p>
      <table style="width:100%;border-collapse:collapse;margin:16px 0">
        <tr><td style="padding:8px;color:#64748b">Kode Booking</td><td style="padding:8px;font-weight:bold">${orderNo}</td></tr>
        <tr><td style="padding:8px;color:#64748b">Jenis Tugas</td><td style="padding:8px">${category}</td></tr>
        <tr><td style="padding:8px;color:#64748b">Deadline</td><td style="padding:8px">${deadline}</td></tr>
        <tr><td style="padding:8px;color:#64748b">Estimasi</td><td style="padding:8px">${rupiah}</td></tr>
      </table>
      <p style="color:#64748b;margin:8px 0"><b>Deskripsi:</b></p>
      <p style="background:#f8fafc;padding:12px;border-radius:8px;color:#334155">${description || '-'}</p>
      <a href="${trackUrl}" style="display:block;text-align:center;background:#2563EB;color:#fff;padding:14px;border-radius:10px;text-decoration:none;font-weight:bold;margin:20px 0">🔍 Cek Status Request</a>
      <p style="color:#64748b;font-size:14px">Engineer kami akan segera menghubungimu via WhatsApp untuk diskusi detail &amp; harga.</p>
    </div>
    <div style="background:#f8fafc;padding:16px;text-align:center;color:#94a3b8;font-size:12px">© 2026 JokiTugasIT.id - Dibuat dengan ❤️ untuk Mahasiswa</div>
  </div>`

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [email],
        subject: `Kode Booking JokiTugasIT - ${orderNo}`,
        html,
      }),
    })

    if (!response.ok) {
      const errText = await response.text()
      console.error('Resend error:', response.status, errText)
      return res.status(502).json({ error: 'Gagal kirim email via Resend', detail: errText.slice(0, 300) })
    }

    return res.status(200).json({ ok: true })
  } catch (err) {
    console.error('Send email error:', err)
    return res.status(500).json({ error: 'Gagal kirim email: ' + err.message })
  }
}
