import { describe, expect, it } from 'vitest'
import {
  crmEnabled, outreachEnabled, campaignsEnabled, referralEnabled, inboundEnabled,
} from '../src/lib/features'

describe('feature flag CRM', () => {
  it('aktif secara default saat env tidak diisi', () => {
    expect(crmEnabled).toBe(true)
  })

  it('bertipe boolean', () => {
    expect(typeof crmEnabled).toBe('boolean')
  })

  it('sub-modul aktif secara default, inbound nonaktif', () => {
    expect(outreachEnabled).toBe(true)
    expect(campaignsEnabled).toBe(true)
    expect(referralEnabled).toBe(true)
    expect(inboundEnabled).toBe(false)
  })
})
