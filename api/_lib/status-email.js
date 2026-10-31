// Template email "status order berubah" — fungsi murni supaya bisa diuji
// tanpa jaringan (lihat tests/status-email.test.js).
import { esc } from './http.js'

export const STATUS_URUTAN = ['new', 'consultation', 'working', 'review', 'done', 'paid']

export const STATUS_LABEL = {
  new: 'Baru masuk',
  consultation: 'Konsultasi',
  working: 'Sedang dikerjakan',
  review: 'Tahap review',
  done: 'Selesai',
  paid: 'Lunas',
}

// Satu baris penjelasan per status: apa artinya untuk klien + apa langkah
// berikutnya. Ditulis dari sudut pandang klien, bukan istilah internal.
export const STATUS_PESAN = {
  new: 'Request kamu sudah kami terima dan masuk antrean.',
  consultation: 'Kami sedang mendiskusikan kebutuhanmu. Engineer akan menghubungimu lewat WhatsApp.',
  working: 'Pengerjaan sudah dimulai. Kami akan kabari lagi saat masuk tahap review.',
  review: 'Hasil sudah masuk tahap pengecekan akhir sebelum diserahkan kepadamu.',
  done: 'Pekerjaan selesai. Silakan cek hasilnya, lalu konfirmasi pelunasan kalau sudah sesuai.',
  paid: 'Pembayaran sudah kami terima dan order ini lunas. Terima kasih!',
}

export const STATUS_SAH = Object.keys(STATUS_LABEL)

export function labelStatus(status) {
  return STATUS_LABEL[String(status || '')] || String(status || '-')
}

export function pesanStatus(status) {
  return STATUS_PESAN[String(status || '')] || 'Status order kamu diperbarui.'
}

/** Posisi status di timeline (0..n-1); -1 kalau tidak dikenal. */
export function posisiStatus(status) {
  return STATUS_URUTAN.indexOf(String(status || ''))
}

export function tautanTrack(orderNo) {
  const dasar = (process.env.APP_URL || 'https://jokitugasit.my.id').replace(/\/+$/, '')
  return `${dasar}/track/${encodeURIComponent(String(orderNo || ''))}`
}

function htmlTimeline(status) {
  const kini = posisiStatus(status)
  return `<table role="presentation" style="width:100%;border-collapse:collapse;margin:18px 0">
    <tr>
      ${STATUS_URUTAN.map((s, i) => {
        const lewat = i <= kini
        const warna = lewat ? '#2563EB' : '#CBD5E1'
        const teks = lewat ? '#0F172A' : '#94A3B8'
        return `<td style="text-align:center;padding:0 2px;font-family:Arial,sans-serif">
          <div style="height:8px;border-radius:4px;background:${warna}"></div>
          <div style="font-size:11px;color:${teks};padding-top:6px;line-height:1.3">${esc(STATUS_LABEL[s])}</div>
        </td>`
      }).join('')}
    </tr>
  </table>`
}

/**
 * HTML email perubahan status.
 * o: { order_no, customer_name, status, category, deadline, deadline_date, quote_amount }
 */
export function htmlStatusUpdate(o, opts = {}) {
  const url = opts.tautan || tautanTrack(o.order_no)
  const label = labelStatus(o.status)
  const pesan = pesanStatus(o.status)
  const nama = esc(o.customer_name || 'Kak')

  return `<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;border:1px solid #e2e8f0;border-radius:16px;overflow:hidden">
    <div style="background:#2563EB;padding:24px;text-align:center">
      <h2 style="color:#fff;margin:0">jokitugasit.my.id</h2>
      <p style="color:#dbeafe;margin:4px 0 0">Update status order kamu</p>
    </div>
    <div style="padding:24px">
      <p>Halo <b>${nama}</b>,</p>
      <p>Ada kabar terbaru untuk order <b>${esc(o.order_no)}</b>.</p>
      <div style="background:#EFF6FF;border:1px solid #BFDBFE;border-radius:12px;padding:16px;margin:16px 0">
        <div style="font-size:12px;letter-spacing:.08em;color:#2563EB;font-weight:bold;text-transform:uppercase">Status sekarang</div>
        <div style="font-size:20px;font-weight:bold;color:#0F172A;margin-top:4px">${esc(label)}</div>
        <div style="color:#334155;margin-top:6px;line-height:1.5">${esc(pesan)}</div>
      </div>
      ${htmlTimeline(o.status)}
      <a href="${esc(url)}" style="display:block;text-align:center;background:#2563EB;color:#fff;padding:14px;border-radius:10px;text-decoration:none;font-weight:bold;margin:20px 0">Lihat detail order</a>
      <p style="color:#64748b;font-size:13px;line-height:1.6">Kalau ada pertanyaan, balas lewat WhatsApp kami di 0851-6633-7257 dengan menyebutkan kode <b>${esc(o.order_no)}</b>.</p>
    </div>
    <div style="background:#f8fafc;padding:16px;text-align:center;color:#94a3b8;font-size:12px">© 2026 jokitugasit.my.id</div>
  </div>`
}

export function subjekStatus(orderNo, status) {
  return `Update order ${orderNo}: ${labelStatus(status)}`
}
