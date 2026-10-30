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

/** Susun tautan wa.me dari nomor + teks pembuka. */
export function waLink(phoneNumber, text = '') {
  const num = String(phoneNumber || '').replace(/[^0-9]/g, '')
  const msg = encodeURIComponent(text)
  return `https://wa.me/${num}${msg ? `?text=${msg}` : ''}`
}
