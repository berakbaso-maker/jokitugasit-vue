import { describe, expect, it } from 'vitest'
import { crmEnabled } from '../src/lib/features'

describe('feature flag CRM', () => {
  it('aktif secara default saat env tidak diisi', () => {
    expect(crmEnabled).toBe(true)
  })

  it('bertipe boolean', () => {
    expect(typeof crmEnabled).toBe('boolean')
  })
})
