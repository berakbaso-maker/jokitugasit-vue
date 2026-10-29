import { normalizeUsername } from './username'

export const CSV_COLUMNS = ['ig_username', 'display_name', 'campus', 'cohort_year']

/**
 * Parser CSV minimal: cukup untuk file yang diekspor spreadsheet.
 * Mendukung field berkutip, koma di dalam kutip, dan CRLF.
 * Tidak memakai library supaya tidak menambah dependensi.
 */
export function parseCsv(raw) {
  const text = String(raw || '').replace(/^\uFEFF/, '')
  const rows = []
  let row = []
  let field = ''
  let inQuotes = false

  for (let i = 0; i < text.length; i += 1) {
    const ch = text[i]

    if (inQuotes) {
      if (ch === '"') {
        if (text[i + 1] === '"') { field += '"'; i += 1 }
        else inQuotes = false
      } else {
        field += ch
      }
      continue
    }

    if (ch === '"') { inQuotes = true; continue }
    if (ch === ',') { row.push(field); field = ''; continue }
    if (ch === '\r') continue
    if (ch === '\n') { row.push(field); rows.push(row); row = []; field = ''; continue }
    field += ch
  }

  if (field.length > 0 || row.length > 0) { row.push(field); rows.push(row) }
  return rows.filter(r => r.some(cell => String(cell).trim() !== ''))
}

/**
 * Ubah CSV jadi payload import + laporan pratinjau yang jujur.
 * Dedupe di sini bersifat preview; database tetap melakukan dedupe final.
 */
export function buildImportPreview(rawCsv) {
  const rows = parseCsv(rawCsv)
  if (rows.length === 0) {
    return { header: [], rows: [], summary: { total: 0, valid: 0, invalid: 0, duplicateInFile: 0 }, errors: [] }
  }

  const header = rows[0].map(h => normalizeUsername(h).replace(/\s+/g, '_'))
  const hasHeader = header.includes('ig_username')
  const dataRows = hasHeader ? rows.slice(1) : rows
  const columns = hasHeader ? header : CSV_COLUMNS

  const seen = new Set()
  const parsed = []
  const errors = []
  let duplicateInFile = 0
  let invalid = 0

  dataRows.forEach((cells, idx) => {
    const lineNo = idx + (hasHeader ? 2 : 1)
    const record = {}
    columns.forEach((col, i) => {
      if (col) record[col] = String(cells[i] ?? '').trim()
    })

    const rawUsername = record.ig_username || ''
    const username = normalizeUsername(rawUsername)

    if (!username) {
      invalid += 1
      errors.push({ line: lineNo, value: rawUsername, reason: 'username kosong' })
      return
    }
    if (!/^[a-z0-9._]{1,30}$/.test(username)) {
      invalid += 1
      errors.push({ line: lineNo, value: rawUsername, reason: 'format username tidak valid' })
      return
    }
    if (seen.has(username)) {
      duplicateInFile += 1
      errors.push({ line: lineNo, value: rawUsername, reason: 'duplikat di dalam file' })
      return
    }
    seen.add(username)

    const cohortRaw = record.cohort_year || ''
    let cohort = null
    if (cohortRaw) {
      const n = Number(cohortRaw)
      if (!Number.isInteger(n) || n < 1990 || n > 2036) {
        invalid += 1
        errors.push({ line: lineNo, value: rawUsername, reason: `angkatan tidak wajar: ${cohortRaw}` })
        return
      }
      cohort = n
    }

    parsed.push({
      ig_username: username,
      display_name: record.display_name || null,
      campus: record.campus || null,
      cohort_year: cohort,
      _line: lineNo,
      _raw: rawUsername,
    })
  })

  return {
    header: columns,
    hasHeader,
    rows: parsed,
    errors,
    summary: {
      total: dataRows.length,
      valid: parsed.length,
      invalid,
      duplicateInFile,
    },
  }
}

export function toCsv(rows, columns) {
  const escape = (value) => {
    const s = value == null ? '' : String(value)
    return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s
  }
  const lines = [columns.join(',')]
  rows.forEach(row => lines.push(columns.map(c => escape(row[c])).join(',')))
  return lines.join('\n')
}

export function downloadCsv(filename, content) {
  const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  URL.revokeObjectURL(url)
}
