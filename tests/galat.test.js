import { describe, expect, it } from 'vitest'
import { adalahGalatJaringan, bisaDiulang, detailGalat, pesanGalat } from '../src/lib/galat'

describe('pesanGalat', () => {
  it('menerjemahkan TypeError Failed to fetch', () => {
    const err = new TypeError('Failed to fetch')
    expect(adalahGalatJaringan(err)).toBe(true)
    expect(pesanGalat(err)).toMatch(/tidak bisa terhubung/i)
    expect(pesanGalat(err)).not.toMatch(/failed to fetch|TypeError/i)
  })

  it('menerjemahkan Load failed (Safari) dan fetch failed (Node)', () => {
    expect(pesanGalat(new TypeError('Load failed'))).toMatch(/tidak bisa terhubung/i)
    expect(pesanGalat(new TypeError('fetch failed'))).toMatch(/tidak bisa terhubung/i)
  })

  it('memetakan kode bisnis dari RPC ke kalimat manusia', () => {
    expect(pesanGalat(new Error('NAMA_WAJIB'))).toBe('Nama wajib diisi.')
    expect(pesanGalat(new Error('KATEGORI_TIDAK_VALID'))).toBe('Kategori tugas tidak dikenali.')
    expect(pesanGalat(new Error('TANGGAL_WAJIB'))).toMatch(/tanggal deadline/i)
  })

  it('memetakan kode PostgREST/Postgres', () => {
    expect(pesanGalat({ code: 'PGRST301', message: 'JWT expired' })).toMatch(/masuk lagi/i)
    expect(pesanGalat({ code: '42501', message: 'permission denied' })).toMatch(/akses ditolak/i)
  })

  it('tidak pernah menampilkan teks teknis mentah', () => {
    const teknis = [
      new Error('relation "public.requests" does not exist'),
      new Error('column requests.quote_amount does not exist'),
      new Error('PGRST202 Could not find the function'),
      new Error('violates row-level security policy'),
      new Error('duplicate key value violates unique constraint'),
    ]
    for (const err of teknis) {
      const hasil = pesanGalat(err)
      expect(hasil).not.toMatch(/PGRST|relation|column|violates|does not exist/i)
      expect(hasil.length).toBeGreaterThan(10)
    }
  })

  it('memakai kalimat error manusia apa adanya', () => {
    expect(pesanGalat(new Error('Nomor order tidak ditemukan. Periksa kembali penulisannya.')))
      .toBe('Nomor order tidak ditemukan. Periksa kembali penulisannya.')
  })

  it('memakai fallback saat error kosong', () => {
    expect(pesanGalat(null, 'Gagal memuat.')).toBe('Gagal memuat.')
    expect(pesanGalat(undefined)).toMatch(/terjadi kesalahan/i)
  })
})

describe('bisaDiulang', () => {
  it('true untuk jaringan & 5xx/429, false untuk validasi', () => {
    expect(bisaDiulang(new TypeError('Failed to fetch'))).toBe(true)
    expect(bisaDiulang({ status: 503 })).toBe(true)
    expect(bisaDiulang({ status: 429 })).toBe(true)
    expect(bisaDiulang(new Error('NAMA_WAJIB'))).toBe(false)
  })
})

describe('detailGalat', () => {
  it('merangkum kode dan pesan asli untuk log', () => {
    const hasil = detailGalat({ name: 'Error', code: 'PGRST202', message: 'not found' })
    expect(hasil).toContain('PGRST202')
    expect(hasil).toContain('not found')
  })

  it('aman untuk null', () => {
    expect(detailGalat(null)).toBe('')
  })
})
