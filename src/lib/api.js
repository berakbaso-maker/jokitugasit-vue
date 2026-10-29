import { supabase } from './supabase'

const ATTACHMENT_BUCKET = 'attachments'


export function formatRupiah(value) {
  if (value == null || Number.isNaN(Number(value))) return 'Rp 0'
  return 'Rp ' + Number(value).toLocaleString('id-ID')
}

// ---------- PUBLIC (anon) ----------

/**
 * Lacak order lewat RPC. Tabel `requests` tidak lagi bisa dibaca anon
 * supaya nama, WhatsApp, catatan internal, dan harga tidak bocor.
 */
export async function getPublicOrder(orderNo) {
  const { data, error } = await supabase.rpc('track_request', {
    p_order_no: String(orderNo || '').trim().toUpperCase(),
  })
  if (error) throw error
  return Array.isArray(data) ? data[0] || null : data || null
}

/**
 * Kirim request lewat RPC. Server yang membuat nomor order dan memaksa
 * status/harga supaya tidak bisa dipalsukan dari browser.
 * Mengembalikan order_no.
 */
export async function createRequest(payload) {
  const { data, error } = await supabase.rpc('create_public_request', {
    p_customer_name: payload.customer_name,
    p_whatsapp: payload.whatsapp,
    p_description: payload.description,
    p_category: payload.category || 'web',
    p_deadline: payload.deadline || 'besok',
    p_deadline_date: payload.deadline_date || null,
    p_link: payload.link || null,
    p_file_url: payload.file_url || null,
    p_email: payload.email || null,
    p_referral_code: payload.referral_code || null,
  })
  if (error) throw error
  return { order_no: data }
}

export async function uploadAttachment(file) {
  const ext = file.name.split('.').pop() || 'bin'
  const path = `requests/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`
  const { error } = await supabase.storage
    .from(ATTACHMENT_BUCKET)
    .upload(path, file, { cacheControl: '3600', upsert: false })
  if (error) throw error
  const { data: publicUrl } = supabase.storage.from(ATTACHMENT_BUCKET).getPublicUrl(path)
  return publicUrl.publicUrl
}

/** Validasi kode referral tanpa membuka data partner. */
export async function validateReferralCode(code) {
  const clean = String(code || '').trim().toUpperCase()
  if (clean.length < 3) return null
  const { data, error } = await supabase.rpc('validate_referral_code', { p_code: clean })
  if (error) throw error
  const row = Array.isArray(data) ? data[0] : data
  return row?.valid ? { referral_code: clean, display_name: row.display_name } : null
}

// ---------- ENGINEER: requests ----------

export async function listRequests(filters = {}) {
  let query = supabase.from('requests').select('*').order('created_at', { ascending: false })
  if (filters.status) query = query.eq('status', filters.status)
  const { data, error } = await query
  if (error) throw error
  return data
}

export async function getRequest(id) {
  const { data, error } = await supabase.from('requests').select('*').eq('id', id).maybeSingle()
  if (error) throw error
  return data
}

export async function updateRequest(id, patch) {
  const { data, error } = await supabase.from('requests').update(patch).eq('id', id).select().single()
  if (error) throw error
  return data
}

export async function listTransactions() {
  const { data, error } = await supabase
    .from('transactions')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}

export function waLink(phoneNumber, text = '') {
  const num = String(phoneNumber || '').replace(/[^0-9]/g, '')
  const msg = encodeURIComponent(text)
  return `https://wa.me/${num}${msg ? `?text=${msg}` : ''}`
}


export const CATEGORY_LABELS = {
  web: 'Website / Web App',
  mobile: 'Aplikasi Mobile',
  desktop: 'Aplikasi Desktop',
  database: 'Database',
  ai: 'AI / Machine Learning',
  debug: 'Debug / Benerin Error',
  skripsi: 'Skripsi / Tugas Akhir',
  tugas_kuliah: 'Tugas Kuliah Dasar',
  design: 'Desain UI/UX',
  lainnya: 'Lainnya',
}

export const STATUS_LABELS = {
  new: 'Baru',
  consultation: 'Konsultasi',
  working: 'Dikerjakan',
  review: 'Review',
  done: 'Selesai',
  paid: 'Lunas',
}

export const DEADLINE_LABELS = {
  hari_ini: 'Hari Ini',
  besok: 'Besok',
  fleksibel: 'Fleksibel',
}

// ---------- PARTNER REFERRAL ----------

export async function createPartner(payload) {
  const { data, error } = await supabase.from('partners').insert(payload).select().single()
  if (error) throw error
  return data
}

export async function listPartners() {
  const { data, error } = await supabase
    .from('partners')
    .select('*')
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}

export async function updatePartner(id, patch) {
  const { data, error } = await supabase.from('partners').update(patch).eq('id', id).select().single()
  if (error) throw error
  return data
}

export function generateReferralCode(name) {
  const clean = (name || 'partner').replace(/[^a-zA-Z]/g, '').slice(0, 6).toUpperCase()
  const num = String(Math.floor(10 + Math.random() * 90))
  return `REF-${clean}${num}`
}

/**
 * Pastikan kode unik. Dipakai sebelum insert partner supaya tabrakan
 * tidak berakhir sebagai error database.
 */
export async function ensureUniqueReferralCode(name) {
  for (let i = 0; i < 8; i += 1) {
    const candidate = generateReferralCode(i === 0 ? name : `${name}${Math.random()}`)
    const { data, error } = await supabase
      .from('partners')
      .select('id')
      .eq('referral_code', candidate)
      .maybeSingle()
    if (error) throw error
    if (!data) return candidate
  }
  throw new Error('Gagal membuat kode referral unik. Coba lagi.')
}

// ---------- COMMISSIONS ----------

/**
 * Komisi dihitung di database (integer rupiah, hanya setelah lunas).
 * UI tidak pernah mengalikan sendiri.
 */
export async function listCommissions(filters = {}) {
  let query = supabase
    .from('commissions')
    .select('*, partners(full_name, whatsapp, referral_code), requests(order_no, customer_name, category, status, quote_amount, discount_amount)')
    .order('created_at', { ascending: false })
  if (filters.status) query = query.eq('status', filters.status)
  if (filters.partnerId) query = query.eq('partner_id', filters.partnerId)
  const { data, error } = await query
  if (error) throw error
  return data
}

export async function markCommissionPaid(commissionId, { proofUrl = null, note = null } = {}) {
  const { data, error } = await supabase.rpc('mark_commission_paid', {
    p_commission_id: commissionId,
    p_proof_url: proofUrl,
    p_note: note,
  })
  if (error) throw error
  return Array.isArray(data) ? data[0] : data
}

export async function recomputeCommission(requestId) {
  const { data, error } = await supabase.rpc('recompute_commission', { p_request_id: requestId })
  if (error) throw error
  return Array.isArray(data) ? data[0] : data
}

// ---------- PAYMENTS ----------

export async function listPayments(requestId = null) {
  let query = supabase.from('payments').select('*').order('paid_at', { ascending: false })
  if (requestId) query = query.eq('request_id', requestId)
  const { data, error } = await query
  if (error) throw error
  return data
}

/**
 * @param {object} payload
 * @param {string} payload.requestId
 * @param {'DP'|'SETTLEMENT'|'REFUND'} payload.kind
 * @param {number} payload.amount  integer rupiah, tanpa titik/desimal
 * @param {string} [payload.idempotencyKey] kirim kunci yang sama saat retry
 */
export async function recordPayment({
  requestId, kind, amount, idempotencyKey = null, method = null, proofUrl = null, paidAt = null, note = null,
}) {
  const { data, error } = await supabase.rpc('record_payment', {
    p_request_id: requestId,
    p_kind: kind,
    p_amount: Math.round(Number(amount)),
    p_idempotency_key: idempotencyKey,
    p_method: method,
    p_proof_url: proofUrl,
    p_paid_at: paidAt || new Date().toISOString(),
    p_note: note,
  })
  if (error) throw error
  return Array.isArray(data) ? data[0] : data
}

// ---------- ANALYTICS ----------

export async function getAnalyticsOverview(from = null, to = null) {
  const { data, error } = await supabase.rpc('analytics_overview', { p_from: from, p_to: to })
  if (error) throw error
  return data
}

export async function getAnalyticsFunnel(from = null, to = null) {
  const { data, error } = await supabase.rpc('analytics_funnel', { p_from: from, p_to: to })
  if (error) throw error
  return data || []
}

/**
 * Portal partner: hanya komisi milik partner ybs, dihitung di server
 * lewat RPC supaya kode partner tidak bisa dipakai mengintip data lain.
 */
export async function getPartnerOverview(code) {
  const { data, error } = await supabase.rpc('partner_portal', {
    p_code: String(code || '').trim().toUpperCase(),
  })
  if (error) throw error
  return data
}
