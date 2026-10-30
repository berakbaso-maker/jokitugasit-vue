import { afterEach, beforeEach, describe, expect, it } from 'vitest'
import {
  extractInstagramEvents,
  requireSchedulerSecret,
  verifyMetaSignature,
} from '../api/_lib/instagram'

function fakeRes() {
  const res = { statusCode: 200, body: null }
  res.status = (code) => {
    res.statusCode = code
    return res
  }
  res.json = (payload) => {
    res.body = payload
    return res
  }
  return res
}

describe('extractInstagramEvents — dedupe key', () => {
  it('memakai id asli Meta bila tersedia', () => {
    const events = extractInstagramEvents({
      entry: [{ id: 'ig1', time: 1700000000, changes: [{ field: 'comments', value: { id: 'c_123' } }] }],
    })
    expect(events).toHaveLength(1)
    expect(events[0].externalId).toBe('c_123')
  })

  it('menghasilkan externalId stabil saat Meta tidak mengirim id', () => {
    const payload = {
      entry: [{ id: 'ig1', changes: [{ field: 'story_insights', value: { media_id: null, metric: { views: 12 } } }] }],
    }
    const first = extractInstagramEvents(payload)
    const second = extractInstagramEvents(payload)
    expect(first[0].externalId).toMatch(/^fallback:/)
    expect(first[0].externalId).toBe(second[0].externalId)
  })

  it('payload berbeda menghasilkan kunci berbeda', () => {
    const a = extractInstagramEvents({
      entry: [{ id: 'ig1', changes: [{ field: 'x', value: { metric: { views: 1 } } }] }],
    })
    const b = extractInstagramEvents({
      entry: [{ id: 'ig1', changes: [{ field: 'x', value: { metric: { views: 2 } } }] }],
    })
    expect(a[0].externalId).not.toBe(b[0].externalId)
  })

  it('pesan DM tanpa mid tetap mendapat kunci', () => {
    const events = extractInstagramEvents({
      entry: [{ id: 'ig1', messaging: [{ sender: { id: 'u1' }, message: { text: 'halo' } }] }],
    })
    expect(events[0].externalId).toMatch(/^fallback:messages:/)
  })
})

describe('requireSchedulerSecret', () => {
  const ORIGINAL = { ...process.env }

  beforeEach(() => {
    process.env.CRON_SECRET = 'cron-secret-abc'
    process.env.IG_AUTOMATION_SECRET = 'automation-secret-xyz'
  })

  afterEach(() => {
    process.env = { ...ORIGINAL }
  })

  it('menerima CRON_SECRET (Vercel Cron)', () => {
    const res = fakeRes()
    const req = { headers: { authorization: 'Bearer cron-secret-abc' } }
    expect(requireSchedulerSecret(req, res)).toBe(true)
    expect(res.statusCode).toBe(200)
  })

  it('menerima IG_AUTOMATION_SECRET (GitHub Actions)', () => {
    const res = fakeRes()
    const req = { headers: { authorization: 'Bearer automation-secret-xyz' } }
    expect(requireSchedulerSecret(req, res)).toBe(true)
  })

  it('menolak tanpa header', () => {
    const res = fakeRes()
    expect(requireSchedulerSecret({ headers: {} }, res)).toBe(false)
    expect(res.statusCode).toBe(401)
  })

  it('menolak secret yang salah', () => {
    const res = fakeRes()
    const req = { headers: { authorization: 'Bearer salah' } }
    expect(requireSchedulerSecret(req, res)).toBe(false)
    expect(res.body).toEqual({ error: 'Unauthorized' })
  })

  it('menolak semua saat kedua secret tidak dikonfigurasi', () => {
    process.env.CRON_SECRET = ''
    process.env.IG_AUTOMATION_SECRET = ''
    const res = fakeRes()
    const req = { headers: { authorization: 'Bearer apa-saja' } }
    expect(requireSchedulerSecret(req, res)).toBe(false)
    expect(res.statusCode).toBe(401)
  })
})

describe('verifyMetaSignature', () => {
  const ORIGINAL = { ...process.env }

  afterEach(() => {
    process.env = { ...ORIGINAL }
  })

  it('menolak bila IG_APP_SECRET kosong', () => {
    delete process.env.IG_APP_SECRET
    expect(verifyMetaSignature(Buffer.from('{}'), 'sha256=abc')).toBe(false)
  })
})
