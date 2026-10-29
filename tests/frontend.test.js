import { describe, expect, it } from 'vitest'
import { buildImportPreview, parseCsv } from '../src/lib/csv'
import { isValidUsername, normalizeUsername } from '../src/lib/username'
import { renderTemplate, unknownPlaceholders } from '../src/lib/template'

describe('normalizeUsername', () => {
  it('membuang @, spasi, dan mengecilkan huruf', () => {
    expect(normalizeUsername('  @Andi.23  ')).toBe('andi.23')
    expect(normalizeUsername('@@SITI')).toBe('siti')
    expect(normalizeUsername('Budi_S')).toBe('budi_s')
  })

  it('menangani null tanpa melempar', () => {
    expect(normalizeUsername(null)).toBe('')
    expect(normalizeUsername(undefined)).toBe('')
  })

  it('memvalidasi format Instagram', () => {
    expect(isValidUsername('andi.23')).toBe(true)
    expect(isValidUsername('@andi.23')).toBe(true)
    expect(isValidUsername('a')).toBe(true)
    expect(isValidUsername('bukan username')).toBe(false)
    expect(isValidUsername('andi-23')).toBe(false)
    expect(isValidUsername('a'.repeat(31))).toBe(false)
    expect(isValidUsername('')).toBe(false)
  })
})

describe('parseCsv', () => {
  it('membaca CSV sederhana', () => {
    const rows = parseCsv('ig_username,display_name\nandi.23,Andi\nsiti_ok,Siti')
    expect(rows).toHaveLength(3)
    expect(rows[1]).toEqual(['andi.23', 'Andi'])
  })

  it('mendukung field berkutip dengan koma', () => {
    const rows = parseCsv('ig_username,campus\nandi.23,"Binus, Kemanggisan"')
    expect(rows[1][1]).toBe('Binus, Kemanggisan')
  })

  it('mendukung kutip ganda di dalam field', () => {
    const rows = parseCsv('ig_username,display_name\nandi.23,"Andi ""Kecil"""')
    expect(rows[1][1]).toBe('Andi "Kecil"')
  })

  it('menangani CRLF dan BOM', () => {
    const rows = parseCsv('\uFEFFig_username\r\nandi.23\r\n')
    expect(rows).toEqual([['ig_username'], ['andi.23']])
  })

  it('mengabaikan baris kosong', () => {
    const rows = parseCsv('ig_username\n\n\nandi.23\n\n')
    expect(rows).toEqual([['ig_username'], ['andi.23']])
  })
})

describe('buildImportPreview', () => {
  it('menormalisasi, mendeteksi duplikat dalam file, dan menolak yang invalid', () => {
    const raw = [
      'ig_username,display_name,campus,cohort_year',
      '  @Andi.23  ,Andi,Binus,2023',
      'andi.23,Duplikat,Binus,2023',
      'bukan username!,X,Binus,2023',
      ',Tanpa Username,Binus,2023',
      'Siti_OK,Siti,Telkom,2022',
    ].join('\n')

    const result = buildImportPreview(raw)

    expect(result.summary.total).toBe(5)
    expect(result.summary.valid).toBe(2)
    expect(result.summary.invalid).toBe(2)
    expect(result.summary.duplicateInFile).toBe(1)
    expect(result.rows.map(r => r.ig_username)).toEqual(['andi.23', 'siti_ok'])
    expect(result.rows[0].campus).toBe('Binus')
    expect(result.rows[0].cohort_year).toBe(2023)
  })

  it('menolak angkatan yang tidak wajar', () => {
    const result = buildImportPreview('ig_username,cohort_year\nandi.23,1800')
    expect(result.summary.valid).toBe(0)
    expect(result.summary.invalid).toBe(1)
    expect(result.errors[0].reason).toContain('angkatan')
  })

  it('menerima CSV tanpa header', () => {
    const result = buildImportPreview('andi.23,Andi,Binus,2023')
    expect(result.hasHeader).toBe(false)
    expect(result.rows[0]).toMatchObject({
      ig_username: 'andi.23', display_name: 'Andi', campus: 'Binus', cohort_year: 2023,
    })
  })

  it('mengembalikan ringkasan kosong untuk input kosong', () => {
    const result = buildImportPreview('')
    expect(result.rows).toHaveLength(0)
    expect(result.summary.total).toBe(0)
  })
})

describe('renderTemplate', () => {
  const prospect = { display_name: 'Andi', campus: 'Binus', cohort_year: 2023 }
  const websiteUrl = 'https://jokitugasit.my.id'

  it('mengisi semua placeholder dari data nyata', () => {
    const out = renderTemplate(
      'Halo {name}, salam kenal dari {campus} angkatan {cohort}. Info: {website_url}',
      { prospect, websiteUrl },
    )
    expect(out.text).toBe('Halo Andi, salam kenal dari Binus angkatan 2023. Info: https://jokitugasit.my.id')
    expect(out.missing).toEqual([])
    expect(out.unknown).toEqual([])
  })

  it('tidak mengarang data yang tidak ada', () => {
    const out = renderTemplate('Halo {name} dari {campus}', { prospect: { display_name: 'Andi' } })
    expect(out.text).toBe('Halo Andi dari [Kampus]')
    expect(out.missing).toEqual(['campus'])
  })

  it('melaporkan placeholder asing tanpa menghapusnya', () => {
    const out = renderTemplate('Halo {name}, kamu semester {semester}', { prospect })
    expect(out.text).toBe('Halo Andi, kamu semester {semester}')
    expect(out.unknown).toEqual(['semester'])
    expect(unknownPlaceholders('{name} {semester}')).toEqual(['semester'])
  })

  it('menerima alias placeholder', () => {
    const out = renderTemplate('{nama} di {kampus}', { prospect })
    expect(out.text).toBe('Andi di Binus')
  })

  it('menangani body kosong', () => {
    expect(renderTemplate('').text).toBe('')
    expect(renderTemplate(null).text).toBe('')
  })
})
