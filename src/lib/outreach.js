import { supabase } from './supabase'
import { isValidUsername, normalizeUsername } from './username'

export { isValidUsername, normalizeUsername }
export { renderTemplate, unknownPlaceholders, placeholderKeys } from './template'

// =============================================================
// Outreach: target accounts, prospects, templates, logs
//
// Semua operasi tulis yang menyentuh status/DNC lewat RPC supaya
// aturan bisnis tidak bisa dilewati dari browser.
// =============================================================

export const PROSPECT_STATUS = {
  NEW: { label: 'Baru', class: 'bg-surface-container text-on-surface-variant' },
  READY_TO_REVIEW: { label: 'Siap Ditinjau', class: 'bg-secondary-container text-on-secondary-container' },
  CONTACTED: { label: 'Sudah Dihubungi', class: 'bg-primary-fixed text-on-primary-fixed' },
  REPLIED: { label: 'Membalas', class: 'bg-tertiary-fixed text-on-tertiary-fixed' },
  INTERESTED_SERVICE: { label: 'Minat Jasa', class: 'bg-success-green/15 text-success-green' },
  INTERESTED_REFERRAL: { label: 'Minat Referral', class: 'bg-success-green/15 text-success-green' },
  NOT_INTERESTED: { label: 'Tidak Minat', class: 'bg-surface-container-high text-on-surface-variant' },
  DO_NOT_CONTACT: { label: 'Jangan Dihubungi', class: 'bg-error-container text-on-error-container' },
  CONVERTED: { label: 'Jadi Klien', class: 'bg-electric-blue/15 text-electric-blue' },
}

export const ACCOUNT_TYPE_LABELS = {
  COHORT: 'Angkatan',
  DEPARTMENT: 'Jurusan',
  STUDENT_ORG: 'Organisasi',
  OTHER: 'Lainnya',
}

export const RELATIONSHIP_LABELS = {
  NEW: 'Belum Dihubungi',
  CONTACTED: 'Sudah Dihubungi',
  PERMISSION_GRANTED: 'Izin Diberikan',
  DECLINED: 'Menolak',
}

export const OUTCOME_LABELS = {
  SENT: 'Pesan Terkirim',
  REPLIED: 'Membalas',
  INTERESTED_SERVICE: 'Minat Jasa',
  INTERESTED_REFERRAL: 'Minat Referral',
  NOT_INTERESTED: 'Tidak Minat',
  NO_RESPONSE: 'Tidak Ada Respons',
  DO_NOT_CONTACT: 'Minta Jangan Dihubungi',
}

export const PERMISSION_BASIS_LABELS = {
  MANUAL_ENTRY: 'Input Manual',
  ADMIN_SHARED_LIST: 'Daftar dari Admin',
  INBOUND_OPT_IN: 'Inbound / Opt-in',
}

// ---------- normalisasi (dipakai untuk preview di UI) ----------

// ---------- target accounts ----------

export async function listTargetAccounts() {
  const { data, error } = await supabase
    .from('target_accounts')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data || []
}

export async function createTargetAccount(payload) {
  const { data, error } = await supabase
    .from('target_accounts')
    .insert({ ...payload, ig_username: normalizeUsername(payload.ig_username) })
    .select()
    .single()
  if (error) throw error
  return data
}

export async function updateTargetAccount(id, patch) {
  const next = { ...patch, updated_at: new Date().toISOString() }
  if (patch.ig_username) next.ig_username = normalizeUsername(patch.ig_username)
  if (patch.relationship_status === 'PERMISSION_GRANTED') {
    next.permission_granted_at = new Date().toISOString()
  }
  const { data, error } = await supabase
    .from('target_accounts')
    .update(next)
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}

// ---------- prospects ----------

export async function listProspects(filters = {}) {
  let query = supabase
    .from('prospects')
    .select('*, target_accounts(ig_username, campus)')
    .order('first_seen_at', { ascending: false })

  if (filters.status) query = query.eq('status', filters.status)
  if (filters.campus) query = query.eq('campus', filters.campus)
  if (filters.sourceAccountId) query = query.eq('source_account_id', filters.sourceAccountId)
  if (filters.search) query = query.ilike('ig_username', `%${normalizeUsername(filters.search)}%`)
  if (filters.limit) query = query.limit(filters.limit)

  const { data, error } = await query
  if (error) throw error
  return data || []
}

/** Antrean outreach: tidak pernah memuat prospek DNC atau yang sudah menolak. */
export async function listOutreachQueue(filters = {}) {
  let query = supabase
    .from('prospects')
    .select('*, target_accounts(ig_username, campus)')
    .eq('do_not_contact', false)
    .in('status', ['NEW', 'READY_TO_REVIEW', 'CONTACTED', 'REPLIED'])
    .order('first_seen_at', { ascending: true })
    .limit(filters.limit || 100)

  if (filters.campus) query = query.eq('campus', filters.campus)
  if (filters.search) query = query.ilike('ig_username', `%${normalizeUsername(filters.search)}%`)

  const { data, error } = await query
  if (error) throw error
  return data || []
}

export async function createProspect(payload) {
  const { data, error } = await supabase
    .from('prospects')
    .insert({
      ...payload,
      ig_username: normalizeUsername(payload.ig_username),
      permission_basis: payload.permission_basis || 'MANUAL_ENTRY',
    })
    .select()
    .single()
  if (error) throw error
  return data
}

/**
 * Catat hasil kontak. RPC menolak prospek DNC dan mengubah status
 * secara konsisten, jadi UI tidak perlu menebak.
 */
export async function logOutreach({
  prospectId, templateId = null, outcome = 'SENT', note = null, channel = 'INSTAGRAM_DM_MANUAL',
}) {
  const { error } = await supabase.rpc('log_outreach', {
    p_prospect_id: prospectId,
    p_template_id: templateId,
    p_outcome: outcome,
    p_note: note,
    p_channel: channel,
  })
  if (error) throw error
}

/** Lepas status DNC secara sengaja (hanya engineer, melalui override). */
export async function clearDoNotContact(prospectId, reason) {
  const { data, error } = await supabase.rpc('clear_do_not_contact', {
    p_prospect_id: prospectId,
    p_reason: reason,
  })
  if (error) throw error
  return data
}

export async function listOutreachLogs(prospectId) {
  const { data, error } = await supabase
    .from('outreach_logs')
    .select('*, dm_templates(name, category)')
    .eq('prospect_id', prospectId)
    .order('sent_at', { ascending: false })
    .limit(20)
  if (error) throw error
  return data || []
}

// ---------- import batch & statistik ----------

const PAGE_SIZE_MAX = 100

function sanitizeSearch(value) {
  // Buang karakter yang punya arti di filter PostgREST.
  return String(value || '').trim().replace(/^@+/, '').replace(/[%,()]/g, ' ').trim()
}

/** Halaman prospek dengan filter di server, bukan di memori. */
export async function listProspectsPage(filters = {}) {
  const pageSize = Math.min(PAGE_SIZE_MAX, Math.max(1, Number(filters.pageSize) || 25))
  const page = Math.max(1, Number(filters.page) || 1)
  const from = (page - 1) * pageSize

  let query = supabase
    .from('prospects')
    .select('*, target_accounts(ig_username, campus)', { count: 'exact' })
    .order('first_seen_at', { ascending: false })
    .range(from, from + pageSize - 1)

  if (filters.status) query = query.eq('status', filters.status)
  if (filters.campus) query = query.eq('campus', filters.campus)

  const search = sanitizeSearch(filters.search)
  if (search) {
    query = query.or(`ig_username.ilike.%${search}%,display_name.ilike.%${search}%`)
  }

  const { data, error, count } = await query
  if (error) throw error
  return { rows: data || [], total: count || 0, page, pageSize }
}

/** Ambil semua baris untuk ekspor, dengan batas aman. */
export async function listAllProspects(filters = {}) {
  const pageSize = PAGE_SIZE_MAX
  const maxPages = 40
  let page = 1
  let total = Infinity
  let rows = []

  while (rows.length < total && page <= maxPages) {
    const result = await listProspectsPage({ ...filters, page, pageSize })
    rows = rows.concat(result.rows)
    total = result.total
    if (!result.rows.length) break
    page += 1
  }

  return rows
}

export async function importProspectsBatch({
  fileName = null, rows, sourceAccount = null, permissionBasis = 'MANUAL_ENTRY', batchId = null,
}) {
  const { data, error } = await supabase.rpc('import_prospects_batch', {
    p_file_name: fileName,
    p_rows: rows,
    p_source_account: sourceAccount,
    p_permission_basis: permissionBasis,
    p_batch_id: batchId,
  })
  if (error) throw error
  return Array.isArray(data) ? data[0] : data
}

export async function listImportBatches(limit = 5) {
  const { data, error } = await supabase
    .from('import_batches')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return data || []
}

/** Daftar kampus unik untuk filter. Kolomnya kecil, bukan data pribadi. */
export async function listProspectCampuses() {
  const { data, error } = await supabase
    .from('prospects')
    .select('campus')
    .not('campus', 'is', null)
    .limit(1000)
  if (error) throw error
  return [...new Set((data || []).map(r => r.campus).filter(Boolean))].sort()
}

export async function getProspectStats() {
  const { data, error } = await supabase.rpc('prospect_stats')
  if (error) throw error
  const row = Array.isArray(data) ? data[0] : data
  return row || { total: 0, in_queue: 0, contacted: 0, interested: 0, converted: 0, dnc: 0 }
}

/** Ubah prospek jadi proyek nyata dan tandai CONVERTED. */
export async function convertProspectToRequest({
  prospectId, category = 'web', description = '', quote = null,
}) {
  const { data, error } = await supabase.rpc('create_request_from_prospect', {
    p_prospect_id: prospectId,
    p_category: category,
    p_description: description || null,
    p_quote: quote === null || quote === '' ? null : Math.round(Number(quote)),
  })
  if (error) throw error
  return Array.isArray(data) ? data[0] : data
}

/**
 * Hapus prospek. Username bisa dimasukkan ke suppression list supaya
 * import berikutnya tidak memunculkannya lagi (permintaan hapus data).
 */
export async function deleteProspect(prospectId, reason, { suppress = true } = {}) {
  const { error } = await supabase.rpc('delete_prospect', {
    p_prospect_id: prospectId,
    p_reason: reason,
    p_suppress: suppress,
  })
  if (error) throw error
}

export async function deleteTargetAccount(accountId) {
  const { error } = await supabase.from('target_accounts').delete().eq('id', accountId)
  if (error) throw error
}

export async function listSuppressions(limit = 100) {
  const { data, error } = await supabase
    .from('prospect_suppressions')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(limit)
  if (error) throw error
  return data || []
}

// ---------- templates ----------

export async function listTemplates({ activeOnly = true } = {}) {
  let query = supabase.from('dm_templates').select('*').order('sort_order')
  if (activeOnly) query = query.eq('is_active', true)
  const { data, error } = await query
  if (error) throw error
  return data || []
}

export async function createTemplate(payload) {
  const { data, error } = await supabase.from('dm_templates').insert(payload).select().single()
  if (error) throw error
  return data
}

export async function updateTemplate(id, patch) {
  const { data, error } = await supabase
    .from('dm_templates')
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}
