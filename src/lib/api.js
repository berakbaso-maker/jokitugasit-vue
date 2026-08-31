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