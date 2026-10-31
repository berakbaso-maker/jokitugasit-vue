// Logika kuitansi — fungsi murni, tanpa Supabase, supaya bisa diuji langsung.
import { summarizePayments, remainingAmount } from './money'

/** Nomor kuitansi yang stabil per order (bisa dipakai ulang saat dicetak). */
export function nomorKuitansi(orderNo) {
  const no = String(orderNo || '').trim().toUpperCase()
  return no ? `INV/${no}` : 'INV/-'
}

/** Total tagihan = quote - diskon (tidak pernah negatif). */
export function totalTagihan(request = {}) {
  const quote = Number(request.quote_amount) || 0
  const diskon = Number(request.discount_amount) || 0
  return Math.max(quote - diskon, 0)
}

/**
 * Ringkasan angka untuk kuitansi.
 * Hanya pembayaran CONFIRMED yang dihitung (PENDING belum uang masuk,
 * VOID sudah dibatalkan) — ini logika yang sama dengan dashboard.
 */
export function ringkasKuitansi(request = {}, payments = []) {
  const total = totalTagihan(request)
  const { net: dibayar } = summarizePayments(payments)
  const sisa = remainingAmount(total, dibayar)
  const adaPembayaran = payments.some((p) => p.status === 'CONFIRMED' && p.kind !== 'REFUND')
  return { total, dibayar, sisa, lunas: total > 0 && sisa === 0, adaPembayaran }
}

export function labelKuitansi(ringkas) {
  if (ringkas.lunas) return 'LUNAS'
  if (ringkas.dibayar > 0) return 'DIBAYAR SEBAGIAN'
  return 'BELUM ADA PEMBAYARAN'
}

/** Baris pembayaran yang layak dicetak (CONFIRMED saja, urut tanggal). */
export function barisPembayaran(payments = []) {
  return payments
    .filter((p) => p.status === 'CONFIRMED')
    .slice()
    .sort((a, b) => String(a.paid_at || a.created_at || '').localeCompare(String(b.paid_at || b.created_at || '')))
}
