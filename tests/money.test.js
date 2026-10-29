import { describe, expect, it } from 'vitest'
import {
  PAYMENT_KIND_LABELS,
  paymentKey,
  remainingAmount,
  summarizePayments,
  toRupiahInteger,
} from '../src/lib/money'

describe('toRupiahInteger', () => {
  it('menerima integer rupiah', () => {
    expect(toRupiahInteger('500000')).toBe(500000)
    expect(toRupiahInteger(150000)).toBe(150000)
  })

  it('menolak desimal, nol, negatif, dan sampah', () => {
    expect(toRupiahInteger('1500.5')).toBeNull()
    expect(toRupiahInteger(0)).toBeNull()
    expect(toRupiahInteger('-1000')).toBeNull()
    expect(toRupiahInteger('abc')).toBeNull()
    expect(toRupiahInteger('')).toBeNull()
    expect(toRupiahInteger(null)).toBeNull()
    expect(toRupiahInteger(undefined)).toBeNull()
  })
})

describe('remainingAmount', () => {
  it('menghitung sisa tagihan', () => {
    expect(remainingAmount(1000000, 500000)).toBe(500000)
    expect(remainingAmount(1000000, 1000000)).toBe(0)
  })

  it('tidak pernah negatif walau kelebihan bayar', () => {
    expect(remainingAmount(300000, 500000)).toBe(0)
  })

  it('aman untuk nilai kosong', () => {
    expect(remainingAmount(null, null)).toBe(0)
  })
})

describe('summarizePayments', () => {
  const rows = [
    { kind: 'DP', amount: 500000, status: 'CONFIRMED' },
    { kind: 'SETTLEMENT', amount: 500000, status: 'CONFIRMED' },
    { kind: 'REFUND', amount: 100000, status: 'CONFIRMED' },
    { kind: 'SETTLEMENT', amount: 250000, status: 'VOID' },
    { kind: 'DP', amount: 99000, status: 'PENDING' },
  ]

  it('hanya menghitung baris CONFIRMED dan mengurangi refund', () => {
    expect(summarizePayments(rows)).toEqual({
      paid: 1000000,
      refunded: 100000,
      pending: 99000,
      net: 900000,
    })
  })

  it('mengabaikan baris VOID sepenuhnya', () => {
    expect(summarizePayments([{ kind: 'SETTLEMENT', amount: 250000, status: 'VOID' }]))
      .toEqual({ paid: 0, refunded: 0, pending: 0, net: 0 })
  })

  it('aman untuk daftar kosong', () => {
    expect(summarizePayments()).toEqual({ paid: 0, refunded: 0, pending: 0, net: 0 })
  })
})

describe('paymentKey', () => {
  it('selalu unik dan berprefix', () => {
    const a = paymentKey('pay')
    const b = paymentKey('pay')
    expect(a).not.toBe(b)
    expect(a.startsWith('pay-')).toBe(true)
  })

  it('menerima prefix kustom', () => {
    expect(paymentKey('settle').startsWith('settle-')).toBe(true)
  })
})

describe('label', () => {
  it('mencakup semua jenis pembayaran', () => {
    expect(Object.keys(PAYMENT_KIND_LABELS).sort()).toEqual(['DP', 'REFUND', 'SETTLEMENT'])
  })
})
