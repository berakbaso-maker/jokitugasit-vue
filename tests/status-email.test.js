import { describe, expect, it } from 'vitest'
import {
  STATUS_SAH, STATUS_URUTAN, htmlStatusUpdate, labelStatus, pesanStatus,
  posisiStatus, subjekStatus, tautanTrack,
} from '../api/_lib/status-email.js'

describe('template email perubahan status', () => {
  it('hanya menerima status resmi', () => {
    expect(STATUS_SAH.sort()).toEqual(['consultation', 'done', 'new', 'paid', 'review', 'working'])
    expect(STATUS_SAH).not.toContain('lunas')
    expect(STATUS_SAH).not.toContain('<script>')
  })

  it('memberi label Indonesia dan fallback aman', () => {
    expect(labelStatus('working')).toBe('Sedang dikerjakan')
    expect(labelStatus('done')).toBe('Selesai')
    expect(labelStatus('apa_saja')).toBe('apa_saja')
    expect(labelStatus(null)).toBe('-')
  })

  it('memberi pesan untuk tiap status dan fallback untuk yang tak dikenal', () => {
    for (const s of STATUS_SAH) expect(pesanStatus(s).length).toBeGreaterThan(10)
    expect(pesanStatus('xxx')).toBe('Status order kamu diperbarui.')
  })

  it('menghitung posisi status di timeline', () => {
    expect(posisiStatus('new')).toBe(0)
    expect(posisiStatus('paid')).toBe(STATUS_URUTAN.length - 1)
    expect(posisiStatus('ngawur')).toBe(-1)
  })

  it('meng-escape nama klien dan nomor order (anti XSS di email)', () => {
    const html = htmlStatusUpdate({
      order_no: 'JT"><script>alert(1)</script>',
      customer_name: '<img src=x onerror=alert(1)>',
      status: 'working',
    })
    expect(html).not.toContain('<script>')
    expect(html).not.toContain('<img src=x')
    expect(html).toContain('&lt;script&gt;')
    expect(html).toContain('&lt;img src=x')
  })

  it('memuat tautan lacak order yang benar', () => {
    const html = htmlStatusUpdate({ order_no: 'JT123456', customer_name: 'Rahul', status: 'review' })
    expect(html).toContain('/track/JT123456')
    expect(tautanTrack('JT123456')).toMatch(/\/track\/JT123456$/)
  })

  it('menandai langkah timeline sampai status sekarang saja', () => {
    const aktif = (html) => (html.match(/#2563EB/g) || []).length
    const newHtml = htmlStatusUpdate({ order_no: 'JT000001', customer_name: 'A', status: 'new' })
    const doneHtml = htmlStatusUpdate({ order_no: 'JT000001', customer_name: 'A', status: 'done' })
    // 3 biru tetap (header, label badge, tombol CTA) + jumlah bar yang aktif
    expect(aktif(newHtml)).toBe(4)
    expect(aktif(doneHtml)).toBe(8)
  })

  it('menyusun subjek email dengan nomor order dan label status', () => {
    expect(subjekStatus('JT999999', 'done')).toBe('Update order JT999999: Selesai')
  })

  it('tidak pernah mengembalikan HTML kosong', () => {
    for (const s of STATUS_SAH) {
      const html = htmlStatusUpdate({ order_no: 'JT111111', customer_name: '', status: s })
      expect(html.length).toBeGreaterThan(400)
      expect(html).toContain('<div')
    }
  })
})
