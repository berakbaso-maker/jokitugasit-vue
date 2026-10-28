// Vercel Serverless Function: Notifikasi instan order tugas baru ke Telegram Engineer
// Endpoint: POST /api/notify-order
// 100% Serverless, tanpa VPS, runtime ~300ms

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  if (req.method === 'OPTIONS') return res.status(204).end()

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' })
  }

  const {
    orderNo,
    customerName,
    whatsapp,
    category,
    deadline,
    deadlineDate,
    description,
    link,
    fileUrl,
  } = req.body || {}

  if (!orderNo || !customerName) {
    return res.status(400).json({ error: 'orderNo dan customerName wajib diisi' })
  }

  let botToken = process.env.TELEGRAM_BOT_TOKEN
  let chatId = process.env.TELEGRAM_NOTIFICATION_CHAT_ID

  // Fallback load .env jika berjalan di lingkungan Node lokal
  if (!botToken || !chatId) {
    try {
      if (typeof process.loadEnvFile === 'function') {
        process.loadEnvFile()
        botToken = process.env.TELEGRAM_BOT_TOKEN
        chatId = process.env.TELEGRAM_NOTIFICATION_CHAT_ID
      }
    } catch {}
  }

  // Jika env belum diset, log dan return 200 agar flow frontend tidak terputus
  if (!botToken || !chatId) {
    console.warn('TELEGRAM_BOT_TOKEN atau TELEGRAM_NOTIFICATION_CHAT_ID belum dikonfigurasi di environment.')
    return res.status(200).json({
      success: false,
      message: 'Telegram credentials belum diset di Vercel Environment Variables',
    })
  }

  // Format kategori dan deadline
  const categoryMap = {
    web: 'Website / Web App',
    mobile: 'Aplikasi Mobile',
    desktop: 'Aplikasi Desktop',
    database: 'Database & API',
    ai: 'AI / Data Science',
    debug: 'Debug / Fix Error',
    skripsi: 'Skripsi / Final Project',
    tugas_kuliah: 'Tugas Kuliah Dasar',
    design: 'Desain UI/UX',
    lainnya: 'Lainnya',
  }

  const deadlineMap = {
    hari_ini: '🔥 HARI INI (Mendesak)',
    besok: '⚡ Besok (Normal)',
    fleksibel: deadlineDate ? `📅 ${deadlineDate}` : '🗓️ Fleksibel',
  }

  const cleanCategory = categoryMap[category] || category || 'Tugas IT'
  const cleanDeadline = deadlineMap[deadline] || deadline || 'Fleksibel'

  // Format nomor WhatsApp internasional untuk wa.me
  const rawWa = String(whatsapp || '').replace(/[^0-9]/g, '')
  const cleanWa = rawWa.startsWith('62') ? rawWa : rawWa.startsWith('0') ? '62' + rawWa.slice(1) : '62' + rawWa
  const waChatUrl = `https://wa.me/${cleanWa}?text=${encodeURIComponent(`Halo ${customerName}, saya engineer jokitugasit.my.id mengenai request ${orderNo}.`)}`
  const trackUrl = `https://jokitugasit.my.id/track/${orderNo}`

  // Escape HTML helper
  const esc = (str) =>
    String(str || '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

  // Template Pesan Telegram (HTML Parse Mode)
  let text = `🔔 <b>ORDER TUGAS BARU MASUK!</b> [<code>#${esc(orderNo)}</code>]\n`
  text += `━━━━━━━━━━━━━━━━━━━━━━\n`
  text += `👤 <b>Mahasiswa</b> : ${esc(customerName)}\n`
  text += `📱 <b>WhatsApp</b>  : <a href="${waChatUrl}">+${cleanWa} (Klik untuk Chat)</a>\n`
  text += `📚 <b>Kategori</b>  : ${esc(cleanCategory)}\n`
  text += `⏰ <b>Deadline</b>  : ${esc(cleanDeadline)}\n\n`
  text += `📝 <b>Masalah / Deskripsi:</b>\n`
  text += `<i>${esc(description || 'Tidak ada deskripsi')}</i>\n`

  if (link) {
    text += `\n🔗 <b>Lampiran Link:</b> <a href="${esc(link)}">${esc(link)}</a>`
  }
  if (fileUrl) {
    text += `\n📁 <b>File Upload:</b> <a href="${esc(fileUrl)}">Unduh Lampiran File</a>`
  }

  text += `\n━━━━━━━━━━━━━━━━━━━━━━\n`
  text += `🔍 <a href="${trackUrl}">Halaman Status Request</a>\n`
  text += `⚡ <i>Segera hubungi mahasiswa untuk diskusi detail & deal harga!</i>`

  try {
    const telegramRes = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: text,
        parse_mode: 'HTML',
        disable_web_page_preview: false,
      }),
    })

    const result = await telegramRes.json()

    if (!result.ok) {
      console.error('Telegram API Error:', result)
      return res.status(200).json({
        success: false,
        error: result.description || 'Gagal mengirim pesan ke Telegram',
      })
    }

    return res.status(200).json({
      success: true,
      messageId: result.result?.message_id,
    })
  } catch (error) {
    console.error('Error sending Telegram notification:', error)
    return res.status(200).json({
      success: false,
      error: error.message,
    })
  }
}
