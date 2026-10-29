/**
 * Helper uang untuk UI. Semua nominal tetap integer rupiah dan
 * perhitungan komisi TIDAK pernah dilakukan di sini — itu tugas
 * database (lihat migration-money-schema.sql).
 */

export const PAYMENT_KIND_LABELS = {
  DP: 'DP',
  SETTLEMENT: 'Pelunasan',
  REFUND: 'Refund',
}

export const PAYMENT_STATUS_LABELS = {
  PENDING: 'Menunggu',
  CONFIRMED: 'Terkonfirmasi',
  VOID: 'Dibatalkan',
}

/**
 * Ubah input form jadi integer rupiah, atau null kalau tidak valid.
 * Menolak desimal dan nilai <= 0 supaya tidak ada pecahan masuk DB.
 */
export function toRupiahInteger(value) {
  if (value === '' || value === null || value === undefined) return null
  const n = Number(value)
  if (!Number.isFinite(n) || !Number.isInteger(n) || n <= 0) return null
  return n
}

/** Sisa tagihan, tidak pernah negatif. */
export function remainingAmount(total, paid) {
  const t = Number(total) || 0
  const p = Number(paid) || 0
  return Math.max(t - p, 0)
}

/**
 * Ringkas pembayaran. Hanya baris CONFIRMED yang dihitung; refund
 * mengurangi nilai bersih, bukan menambah.
 */
export function summarizePayments(payments = []) {
  let paid = 0
  let refunded = 0
  let pending = 0

  for (const p of payments) {
    const amount = Number(p.amount) || 0
    if (p.status === 'PENDING') {
      pending += amount
      continue
    }
    if (p.status !== 'CONFIRMED') continue
    if (p.kind === 'REFUND') refunded += amount
    else paid += amount
  }

  return { paid, refunded, pending, net: Math.max(paid - refunded, 0) }
}

/** Kunci idempotensi unik per percobaan submit. */
export function paymentKey(prefix = 'pay') {
  const rand = typeof crypto !== 'undefined' && crypto.randomUUID
    ? crypto.randomUUID()
    : `${Date.now()}-${Math.random().toString(36).slice(2, 10)}`
  return `${prefix}-${rand}`
}
