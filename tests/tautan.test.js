import { describe, expect, it } from 'vitest'
import { normalisasiWa, waLink } from '../src/lib/tautan.js'

describe('normalisasi nomor WhatsApp', () => {
  it('menormalkan nomor Indonesia ke format 62', () => {
    expect(normalisasiWa('0812-3456-7890')).toBe('6281234567890')
    expect(normalisasiWa('81234567890')).toBe('6281234567890')
    expect(normalisasiWa('6281234567890')).toBe('6281234567890')
    expect(normalisasiWa('+62 812 3456 7890')).toBe('6281234567890')
  })

  it('memperbaiki nomor yang salah tulis 6208...', () => {
    expect(normalisasiWa('620812345678')).toBe('62812345678')
  })

  it('tidak menambah 62 dua kali (bug nomor ganda)', () => {
    const nomorDb = '6281200088888'          // tersimpan apa adanya dari form
    expect(normalisasiWa(nomorDb)).toBe(nomorDb)
    expect(waLink(nomorDb)).toBe('https://wa.me/6281200088888')
    // dulu: waLink('62' + nomorDb) menghasilkan 626281200088888
    expect(waLink('62' + nomorDb)).not.toContain('6262')
  })

  it('mengembalikan string kosong kalau tidak ada digit', () => {
    expect(normalisasiWa('')).toBe('')
    expect(normalisasiWa(null)).toBe('')
    expect(normalisasiWa('abc')).toBe('')
    expect(waLink('')).toBe('https://wa.me/')
  })

  it('tetap menyertakan teks yang sudah di-encode', () => {
    expect(waLink('6281200088888', 'Halo kakak, order JT123456')).toContain('?text=Halo%20kakak%2C%20order%20JT123456')
  })
})
