import { supabase } from './supabase'

const ATTACHMENT_BUCKET = 'attachments'


export function formatRupiah(value) {
  if (value == null || Number.isNaN(Number(value))) return 'Rp 0'
  return 'Rp ' + Number(value).toLocaleString('id-ID')
}

export async function getPublicOrder(orderNo) {
  const { data, error } = await supabase
    .from('requests')
    .select('*')
    .eq('order_no', orderNo)
    .maybeSingle()
  if (error) throw error
  return data
}

export async function createRequest(payload) {
  const { data, error } = await supabase.from('requests').insert(payload).select().single()
  if (error) throw error
  return data
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

export async function getPartnerByCode(code) {
  if (!code || code.trim().length < 3) return null
  const { data, error } = await supabase
    .from('partners')
    .select('id,full_name,referral_code,status')
    .eq('referral_code', code.trim().toUpperCase())
    .eq('status', 'active')
    .maybeSingle()
  if (error) return null
  return data
}

export function generateReferralCode(name) {
  const clean = (name || 'partner').replace(/[^a-zA-Z]/g, '').slice(0, 6).toUpperCase()
  const num = String(Math.floor(10 + Math.random() * 90))
  return `REF-${clean}${num}`
}

// ---------- COMMISSION TRACKING ----------

export async function listReferralRequests() {
  const { data, error } = await supabase
    .from('requests')
    .select('*')
    .not('referral_code', 'is', null)
    .order('created_at', { ascending: false })
  if (error) throw error
  return data
}

export async function markCommissionPaid(requestId) {
  const { data, error } = await supabase
    .from('requests')
    .update({ commission_paid: true })
    .eq('id', requestId)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function getPartnerOverview(code) {
  if (!code) return null
  const cleanCode = code.trim().toUpperCase()
  const { data: partner, error: pErr } = await supabase
    .from('partners')
    .select('*')
    .eq('referral_code', cleanCode)
    .maybeSingle()
  if (pErr || !partner) return null

  const { data: requests } = await supabase
    .from('requests')
    .select('order_no, category, status, quote_amount, commission_paid, created_at')
    .eq('referral_code', cleanCode)
    .order('created_at', { ascending: false })

  const reqList = requests || []
  const totalEarned = reqList
    .filter(r => r.commission_paid && r.quote_amount)
    .reduce((sum, r) => sum + (r.quote_amount * 0.1), 0)
  const pendingEarned = reqList
    .filter(r => !r.commission_paid && ['done', 'paid', 'review'].includes(r.status) && r.quote_amount)
    .reduce((sum, r) => sum + (r.quote_amount * 0.1), 0)

  return {
    partner,
    requests: reqList,
    stats: {
      totalReferrals: reqList.length,
      dealCount: reqList.filter(r => ['working', 'review', 'done', 'paid'].includes(r.status)).length,
      totalEarned,
      pendingEarned,
    },
  }
}