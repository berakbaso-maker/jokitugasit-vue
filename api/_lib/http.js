// Helper HTTP untuk endpoint server: origin whitelist + escape HTML.
// Dipakai /api/notify-order dan /api/send-email.

const ORIGIN_DIIZINKAN = [
  'https://jokitugasit.my.id',
  'https://www.jokitugasit.my.id',
  'https://jokitugasit-vue.vercel.app',
]

export function izinkanOrigin(req, res, methods = 'POST, OPTIONS') {
  const asal = String(req.headers.origin || '')
  const lokal = /^http:\/\/localhost(:\d+)?$/.test(asal)
  if (ORIGIN_DIIZINKAN.includes(asal) || lokal) {
    res.setHeader('Access-Control-Allow-Origin', asal)
    res.setHeader('Vary', 'Origin')
  }
  res.setHeader('Access-Control-Allow-Methods', methods)
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  if (req.method === 'OPTIONS') {
    res.status(204).end()
    return true
  }
  return false
}

const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }

/** Escape lengkap (termasuk kutip) untuk HTML dan parse_mode Telegram. */
export function esc(nilai) {
  return String(nilai ?? '').replace(/[&<>"']/g, (c) => ESC[c])
}

/** Hanya izinkan http(s) http, supaya link di pesan tidak jadi tg:// atau javascript:. */
export function urlAman(nilai) {
  const teks = String(nilai ?? '').trim()
  if (!/^https?:\/\//i.test(teks)) return ''
  return esc(teks)
}

export function ambilOrderNo(body) {
  const nilai = String(body?.orderNo ?? body?.order_no ?? '').trim().toUpperCase()
  return /^JT\d{6}$/.test(nilai) ? nilai : ''
}
