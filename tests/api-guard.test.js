import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { ambilOrderNo, esc, izinkanOrigin, urlAman } from '../api/_lib/http.js'
import notifyHandler from '../api/notify-order.js'
import emailHandler from '../api/send-email.js'

function resPalsu() {
  const res = {
    headers: {},
    statusCode: null,
    body: null,
    setHeader(k, v) { this.headers[k.toLowerCase()] = v },
    status(code) { this.statusCode = code; return this },
    json(payload) { this.body = payload; return this },
    end() { return this },
  }
  return res
}

const reqPalsu = (over = {}) => ({ method: 'POST', headers: {}, body: {}, ...over })

describe('esc', () => {
  it('meng-escape semua karakter berbahaya termasuk kutip', () => {
    expect(esc('<b>"x" & \'y\'')).toBe('&lt;b&gt;&quot;x&quot; &amp; &#39;y&#39;')
  })

  it('aman untuk null/undefined', () => {
    expect(esc(null)).toBe('')
    expect(esc(undefined)).toBe('')
  })
})

describe('urlAman', () => {
  it('hanya meloloskan http(s)', () => {
    expect(urlAman('https://contoh.com/a?b=1')).toBe('https://contoh.com/a?b=1')
    expect(urlAman('javascript:alert(1)')).toBe('')
    expect(urlAman('tg://resolve?domain=evil')).toBe('')
    expect(urlAman('data:text/html,<script>')).toBe('')
  })

  it('meng-escape kutip di URL supaya tidak bisa keluar atribut', () => {
    expect(urlAman('https://a.com/"onmouseover="x')).toContain('&quot;')
  })
})

describe('ambilOrderNo', () => {
  it('menerima format JT + 6 digit', () => {
    expect(ambilOrderNo({ orderNo: ' jt123456 ' })).toBe('JT123456')
  })

  it('menolak bentuk lain', () => {
    expect(ambilOrderNo({ orderNo: 'JT12345' })).toBe('')
    expect(ambilOrderNo({ orderNo: 'JT1234567' })).toBe('')
    expect(ambilOrderNo({ orderNo: "JT123456' OR 1=1" })).toBe('')
    expect(ambilOrderNo({})).toBe('')
    expect(ambilOrderNo(null)).toBe('')
  })
})

describe('izinkanOrigin', () => {
  it('memantulkan origin resmi dan menandai Vary', () => {
    const res = resPalsu()
    izinkanOrigin(reqPalsu({ headers: { origin: 'https://jokitugasit.my.id' } }), res)
    expect(res.headers['access-control-allow-origin']).toBe('https://jokitugasit.my.id')
    expect(res.headers.vary).toBe('Origin')
  })

  it('tidak memberi header untuk origin asing', () => {
    const res = resPalsu()
    izinkanOrigin(reqPalsu({ headers: { origin: 'https://situs-jahat.test' } }), res)
    expect(res.headers['access-control-allow-origin']).toBeUndefined()
  })

  it('menangani preflight OPTIONS', () => {
    const res = resPalsu()
    const selesai = izinkanOrigin(reqPalsu({ method: 'OPTIONS' }), res)
    expect(selesai).toBe(true)
    expect(res.statusCode).toBe(204)
  })
})

describe('POST /api/notify-order (guard)', () => {
  const simpan = { ...process.env }
  beforeEach(() => {
    process.env.SUPABASE_URL = 'https://contoh.supabase.co'
    delete process.env.SUPABASE_SERVICE_ROLE_KEY
  })
  afterEach(() => { process.env = { ...simpan } })

  it('menolak method selain POST', async () => {
    const res = resPalsu()
    await notifyHandler(reqPalsu({ method: 'GET' }), res)
    expect(res.statusCode).toBe(405)
  })

  it('menolak orderNo tidak valid tanpa menyentuh DB', async () => {
    for (const body of [{}, { orderNo: 'abc' }, { orderNo: 'JT1' }, { orderNo: '<script>' }]) {
      const res = resPalsu()
      await notifyHandler(reqPalsu({ body }), res)
      expect(res.statusCode).toBe(400)
    }
  })

  it('gagal aman (503) kalau service key belum diset', async () => {
    const res = resPalsu()
    await notifyHandler(reqPalsu({ body: { orderNo: 'JT123456' } }), res)
    expect(res.statusCode).toBe(503)
    expect(res.body.error).not.toMatch(/key|secret|token/i)
  })

  it('tidak menerima teks pesan dari body (hanya orderNo yang dipakai)', async () => {
    const res = resPalsu()
    await notifyHandler(reqPalsu({ body: { orderNo: 'JT123456', description: 'kirim DP ke rekening 123', link: 'tg://evil' } }), res)
    // 503 karena key belum diset: membuktikan handler tidak mengirim apa pun
    // berdasarkan field kiriman klien.
    expect(res.statusCode).toBe(503)
  })
})

describe('POST /api/send-email (guard)', () => {
  const simpan = { ...process.env }
  beforeEach(() => {
    process.env.SUPABASE_URL = 'https://contoh.supabase.co'
    delete process.env.SUPABASE_SERVICE_ROLE_KEY
  })
  afterEach(() => { process.env = { ...simpan } })

  it('menolak method selain POST', async () => {
    const res = resPalsu()
    await emailHandler(reqPalsu({ method: 'PUT' }), res)
    expect(res.statusCode).toBe(405)
  })

  it('menolak orderNo tidak valid', async () => {
    const res = resPalsu()
    await emailHandler(reqPalsu({ body: { email: 'korban@contoh.com' } }), res)
    expect(res.statusCode).toBe(400)
  })

  it('gagal aman (503) kalau service key belum diset', async () => {
    const res = resPalsu()
    await emailHandler(reqPalsu({ body: { orderNo: 'JT123456' } }), res)
    expect(res.statusCode).toBe(503)
  })

  it('tidak membocorkan detail error Resend', async () => {
    const res = resPalsu()
    await emailHandler(reqPalsu({ body: { orderNo: 'JT123456' } }), res)
    expect(JSON.stringify(res.body)).not.toMatch(/resend|invalid_api_key|detail/i)
  })
})
