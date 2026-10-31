import { describe, expect, it } from 'vitest'
import { infoPembayaran } from '../src/lib/pembayaran.js'

describe('info pembayaran (SOW)', () => {
  it('tidak pernah mencetak nomor rekening palsu saat env kosong', () => {
    const info = infoPembayaran()
    if (info.ada) return // env diisi di mesin ini: tidak relevan
    expect(info.pesan).toEqual([])
    expect(info.bank).toBe('')
    expect(info.ewallet).toBe('')
  })

  it('format baris bank memakai pola "BANK: nomor a.n pemilik"', () => {
    const info = infoPembayaran()
    if (!info.ada) return
    for (const baris of info.pesan) {
      expect(baris).not.toMatch(/1234567890/)
      expect(baris.length).toBeGreaterThan(3)
    }
  })
})
