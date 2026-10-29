/**
 * Normalisasi username Instagram.
 * Cermin dari public.normalize_ig_username() di database — database
 * tetap sumber kebenaran, ini hanya untuk preview/pemakaian di UI.
 */
export function normalizeUsername(input) {
  return String(input ?? '').trim().replace(/^@+/, '').toLowerCase()
}

export function isValidUsername(value) {
  return /^[a-z0-9._]{1,30}$/.test(normalizeUsername(value))
}
