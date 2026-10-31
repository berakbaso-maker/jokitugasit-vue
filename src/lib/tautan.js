/**
 * Utilitas tautan murni — tanpa dependensi jaringan.
 *
 * Dipisahkan dari `api.js` supaya komponen yang cuma butuh menyusun tautan
 * WhatsApp (FooterBar, halaman marketing) tidak ikut menarik
 * `@supabase/supabase-js` ke dalam bundel awal. Sebelumnya seluruh halaman
 * publik mengunduh Supabase hanya karena FooterBar.
 */

/** Nomor WhatsApp resmi. */
export const NOMOR_WA = '6285166337257'

/**
 * Normalisasi nomor Indonesia ke format 62...
 * - "0812..."  -> "62812..."
 * - "812..."   -> "62812..."
 * - "62812..." -> tetap
 * - "620812..." (salah tulis) -> "62812..."
 * Mengembalikan '' kalau tidak ada digit.
 */
export function normalisasiWa(nomor) {
  let n = String(nomor || '').replace(/[^0-9]/g, '')
  if (!n) return ''
  if (n.startsWith('620')) n = '62' + n.slice(3)
  else if (n.startsWith('6262')) n = '62' + n.slice(4) // "62"+"62..." (bug lama pemanggil)
  else if (n.startsWith('0')) n = '62' + n.slice(1)
  else if (!n.startsWith('62')) n = '62' + n
  return n
}

/** Susun tautan wa.me dari nomor + teks pembuka. Nomor dinormalisasi dulu. */
export function waLink(phoneNumber, text = '') {
  const num = normalisasiWa(phoneNumber)
  const msg = encodeURIComponent(text)
  return `https://wa.me/${num}${msg ? `?text=${msg}` : ''}`
}
