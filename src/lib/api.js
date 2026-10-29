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

const MAX_ATTACHMENT_BYTES = 10 * 1024 * 1024
const ATTACHMENT_EXTENSIONS = ['pdf', 'zip', 'png', 'jpg', 'jpeg', 'webp', 'txt']
const MIME_BY_EXTENSION = {
  pdf: 'application/pdf',
  zip: 'application/zip',
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  webp: 'image/webp',
  txt: 'text/plain',
}

/**
 * Upload ke bucket privat. Mengembalikan PATH, bukan URL publik.
 * Bucket harus privat (lihat migration-hardening.sql); akses dibuka
 * lewat signed URL saat engineer menekan "Lihat lampiran".
 */
export async function uploadAttachment(file) {
  if (!file) throw new Error('File tidak ditemukan.')
  if (file.size > MAX_ATTACHMENT_BYTES) {
    throw new Error('Ukuran file maksimal 10 MB.')
  }

  const ext = (file.name.split('.').pop() || '').toLowerCase()
  if (!ATTACHMENT_EXTENSIONS.includes(ext)) {
    throw new Error('Tipe file tidak didukung. Gunakan PDF, ZIP, gambar, atau TXT.')
  }

  // Sebagian browser mengosongkan file.type (mis. ZIP); pakai ekstensi.
  const contentType = file.type || MIME_BY_EXTENSION[ext]
  const path = `requests/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`
  const { error } = await supabase.storage
    .from(ATTACHMENT_BUCKET)
    .upload(path, file, { cacheControl: '3600', upsert: false, contentType })
  if (error) throw error
  return path
}

/** URL sementara untuk lampiran privat. */
export async function getAttachmentSignedUrl(path, expiresIn = 3600) {
  const { data, error } = await supabase.storage
    .from(ATTACHMENT_BUCKET)
    .createSignedUrl(path, expiresIn)
  if (error) throw error
  return data.signedUrl
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

/**
 * @deprecated Tabel `transactions` adalah data lama yang tidak lagi ditulis
 * aplikasi. Sumber kebenaran pendapatan sekarang `payments` + `commissions`
 * (lihat listPayments/listCommissions dan /earnings). Dipertahankan hanya
 * supaya data historis masih bisa dibaca manual.
 */
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

/** Kanal masuknya klien. Dipakai untuk membandingkan sumber akuisisi. */
export const SOURCE_LABELS = {
  DIRECT_DM: 'Direct DM',
  ADMIN_SHARE: 'Dibagikan Admin',
  REFERRAL: 'Referral Partner',
  INBOUND: 'Website Inbound',
  OTHER: 'Lainnya / Tidak Diketahui',
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

export function generateReferralCode() {
  // Fallback lokal saja; produksi memakai generate_referral_code() di DB.
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let code = 'REF-'
  for (let i = 0; i < 8; i += 1) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)]
  }
  return code
}

/**
 * Pastikan kode unik. Dipakai sebelum insert partner supaya tabrakan
 * tidak berakhir sebagai error database.
 */
export async function ensureUniqueReferralCode() {
  // Kode dibuat di database (8 karakter acak) supaya tidak bisa ditebak.
  const { data, error } = await supabase.rpc('generate_referral_code')
  if (!error && data) return data

  // Fallback untuk database yang belum menjalankan migration-hardening.
  for (let i = 0; i < 8; i += 1) {
    const candidate = generateReferralCode('')
    const { data: existing, error: lookupError } = await supabase
      .from('partners')
      .select('id')
      .eq('referral_code', candidate)
      .maybeSingle()
    if (lookupError) throw lookupError
    if (!existing) return candidate
  }
  throw new Error('Gagal membuat kode referral unik. Coba lagi.')
}

/** Rotasi kode partner (kode lama langsung tidak berlaku). */
export async function rotatePartnerCode(partnerId) {
  const { data, error } = await supabase.rpc('rotate_partner_code', {
    p_partner_id: partnerId,
  })
  if (error) throw error
  return data
}

/** Pendaftaran partner publik; kode dibuat server-side. */
export async function registerPartner({ fullName, whatsapp, campus = null, ewalletInfo = null }) {
  const { data, error } = await supabase.rpc('register_partner', {
    p_full_name: fullName,
    p_whatsapp: whatsapp,
    p_campus: campus,
    p_ewallet_info: ewalletInfo,
  })
  if (error) throw error
  return Array.isArray(data) ? data[0] : data
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
  if (filters.requestId) query = query.eq('request_id', filters.requestId)
  if (filters.limit) query = query.limit(filters.limit)
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

export async function listPayments(requestId = null, { limit = null } = {}) {
  let query = supabase
    .from('payments')
    .select('*, requests(order_no, customer_name, category)')
    .order('paid_at', { ascending: false, nullsFirst: false })
  if (requestId) query = query.eq('request_id', requestId)
  if (limit) query = query.limit(limit)
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

/**
 * Batalkan pembayaran yang salah input. Baris tidak dihapus; status
 * jadi VOID + alasan, lalu komisi dan status proyek dihitung ulang
 * oleh database.
 */
export async function voidPayment(paymentId, reason) {
  const { data, error } = await supabase.rpc('void_payment', {
    p_payment_id: paymentId,
    p_reason: reason,
  })
  if (error) throw error
  return Array.isArray(data) ? data[0] : data
}

// ---------- ANALYTICS ----------

export async function getAnalyticsOverview(from = null, to = null, campus = null) {
  const { data, error } = await supabase.rpc('analytics_overview', {
    p_from: from,
    p_to: to,
    p_campus: campus || null,
  })
  if (error) throw error
  return data
}

export async function getAnalyticsFunnel(from = null, to = null, campus = null) {
  const { data, error } = await supabase.rpc('analytics_funnel', {
    p_from: from,
    p_to: to,
    p_campus: campus || null,
  })
  if (error) throw error
  return data || []
}

export async function getAnalyticsCampuses() {
  const { data, error } = await supabase.rpc('analytics_campuses')
  if (error) throw error
  return (data || []).map(row => row.campus).filter(Boolean)
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
