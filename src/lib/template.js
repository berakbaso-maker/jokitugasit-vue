const PLACEHOLDER_ALIASES = {
  name: ['name', 'nama', 'display_name'],
  campus: ['campus', 'kampus'],
  cohort: ['cohort', 'angkatan', 'cohort_year'],
  website_url: ['website_url', 'website', 'link'],
}

export const SUPPORTED_PLACEHOLDERS = Object.values(PLACEHOLDER_ALIASES).flat()

const FALLBACK = {
  name: '[Nama]',
  campus: '[Kampus]',
  cohort: '[Angkatan]',
  website_url: '[Link]',
}

export function placeholderKeys(body) {
  return [...new Set([...String(body || '').matchAll(/\{(\w+)\}/g)].map(m => m[1]))]
}

export function unknownPlaceholders(body) {
  return placeholderKeys(body).filter(
    key => !SUPPORTED_PLACEHOLDERS.includes(key.toLowerCase()),
  )
}

/**
 * Isi placeholder dari data yang benar-benar tersedia.
 *
 * Aturan: tidak pernah mengarang data. Placeholder yang datanya kosong
 * diganti fallback yang terlihat jelas ([Nama]) dan dilaporkan lewat
 * `missing`, supaya pengguna menyadarinya sebelum menekan kirim.
 * Placeholder yang tidak dikenal dibiarkan apa adanya dan dilaporkan
 * lewat `unknown`.
 */
export function renderTemplate(body, { prospect = {}, websiteUrl = '' } = {}) {
  const values = {
    name: prospect.display_name || prospect.name || '',
    campus: prospect.campus || '',
    cohort: prospect.cohort_year ? String(prospect.cohort_year) : '',
    website_url: websiteUrl || '',
  }

  const filled = []
  const missing = []
  const unknown = []

  const text = String(body || '').replace(/\{(\w+)\}/g, (match, rawKey) => {
    const key = rawKey.toLowerCase()
    const canonical = Object.keys(PLACEHOLDER_ALIASES)
      .find(k => PLACEHOLDER_ALIASES[k].includes(key))

    if (!canonical) {
      unknown.push(rawKey)
      return match
    }

    const value = values[canonical]
    if (!value) {
      missing.push(canonical)
      return FALLBACK[canonical]
    }

    filled.push(canonical)
    return value
  })

  return {
    text,
    filled: [...new Set(filled)],
    missing: [...new Set(missing)],
    unknown: [...new Set(unknown)],
  }
}
