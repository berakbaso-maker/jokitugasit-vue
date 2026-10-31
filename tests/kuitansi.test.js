import { describe, expect, it } from 'vitest'
import { barisPembayaran, labelKuitansi, nomorKuitansi, ringkasKuitansi, totalTagihan } from '../src/lib/kuitansi.js'

describe('kuitansi', () => {
  it('membuat nomor kuitansi dari nomor order', () => {
    expect(nomorKuitansi('jt123456')).toBe('INV/JT123456')
    expect(nomorKuitansi(' JT999999 ')).toBe('INV/JT999999')
    expect(nomorKuitansi('')).toBe('INV/-')
    expect(nomorKuitansi(null)).toBe('INV/-')
  })

  it('menghitung total setelah diskon, tidak pernah negatif', () => {
    expect(totalTagihan({ quote_amount: 500000, discount_amount: 50000 })).toBe(450000)
    expect(totalTagihan({ quote_amount: 500000 })).toBe(500000)
    expect(totalTagihan({ quote_amount: 100000, discount_amount: 250000 })).toBe(0)
    expect(totalTagihan({})).toBe(0)
    expect(totalTagihan({ quote_amount: '250000', discount_amount: '50000' })).toBe(200000)
  })

  it('hanya menghitung pembayaran CONFIRMED (PENDING/VOID diabaikan)', () => {
    const bayar = [
      { amount: 200000, status: 'CONFIRMED', kind: 'DP' },
      { amount: 50000, status: 'PENDING', kind: 'SETTLEMENT' },
      { amount: 99999, status: 'VOID', kind: 'DP' },
    ]
    expect(ringkasKuitansi({ quote_amount: 400000 }, bayar)).toEqual({
      total: 400000, dibayar: 200000, sisa: 200000, lunas: false, adaPembayaran: true,
    })
  })

  it('menandai lunas hanya kalau sisa 0 dan ada tagihan', () => {
    expect(ringkasKuitansi({ quote_amount: 300000 }, [{ amount: 300000, status: 'CONFIRMED', kind: 'SETTLEMENT' }]).lunas).toBe(true)
    expect(ringkasKuitansi({ quote_amount: 300000 }, [{ amount: 300000, status: 'PENDING', kind: 'SETTLEMENT' }]).lunas).toBe(false)
    expect(ringkasKuitansi({ quote_amount: 0 }, [{ amount: 0, status: 'CONFIRMED' }]).lunas).toBe(false)
  })

  it('mengurangi refund dari jumlah dibayar', () => {
    const bayar = [
      { amount: 300000, status: 'CONFIRMED', kind: 'DP' },
      { amount: 100000, status: 'CONFIRMED', kind: 'REFUND' },
    ]
    const r = ringkasKuitansi({ quote_amount: 300000 }, bayar)
    expect(r.dibayar).toBe(200000)
    expect(r.sisa).toBe(100000)
  })

  it('memberi label Indonesia yang jelas', () => {
    expect(labelKuitansi({ lunas: true, dibayar: 100 })).toBe('LUNAS')
    expect(labelKuitansi({ lunas: false, dibayar: 100 })).toBe('DIBAYAR SEBAGIAN')
    expect(labelKuitansi({ lunas: false, dibayar: 0 })).toBe('BELUM ADA PEMBAYARAN')
  })

  it('baris pembayaran hanya CONFIRMED dan terurut', () => {
    const rows = barisPembayaran([
      { status: 'CONFIRMED', amount: 2, created_at: '2026-03-02' },
      { status: 'VOID', amount: 9, created_at: '2026-03-01' },
      { status: 'CONFIRMED', amount: 1, created_at: '2026-03-01' },
    ])
    expect(rows.map((r) => r.amount)).toEqual([1, 2])
  })
})
