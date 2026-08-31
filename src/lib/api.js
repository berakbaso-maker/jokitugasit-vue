import { supabase } from './supabase'

const ATTACHMENT_BUCKET = 'attachments'
// TEMP MOCK MODE: ubah ke false setelah Supabase sudah terhubung.
export const USE_MOCK_DATA = true

export const MOCK_REQUESTS = [
  { id: 'mock-new', order_no: 'TEST-NEW', customer_name: 'Dummy New', whatsapp: '81200000001', category: 'web', deadline: 'besok', deadline_date: null, description: 'Dummy request untuk menguji status New.', status: 'new', quote_amount: null, link: null, file_url: null },
  { id: 'mock-consultation', order_no: 'TEST-CONSULT', customer_name: 'Dummy Consultation', whatsapp: '81200000002', category: 'ai', deadline: 'fleksibel', deadline_date: '2026-09-01', description: 'Dummy request untuk menguji status Consultation.', status: 'consultation', quote_amount: 150000, link: null, file_url: null },
  { id: 'mock-working', order_no: 'TEST-WORKING', customer_name: 'Dummy Working', whatsapp: '81200000003', category: 'mobile', deadline: 'hari_ini', deadline_date: null, description: 'Dummy request untuk menguji status Working.', status: 'working', quote_amount: 350000, link: 'https://github.com/example/mobile-project', file_url: null },
  { id: 'mock-review', order_no: 'TEST-REVIEW', customer_name: 'Dummy Review', whatsapp: '81200000004', category: 'data', deadline: 'besok', deadline_date: null, description: 'Dummy request untuk menguji status Review.', status: 'review', quote_amount: 275000, link: null, file_url: null },
  { id: 'mock-done', order_no: 'TEST-DONE', customer_name: 'Dummy Done', whatsapp: '81200000005', category: 'web', deadline: 'fleksibel', deadline_date: '2026-09-08', description: 'Dummy request untuk menguji status Done.', status: 'done', quote_amount: 450000, link: null, file_url: null },
  { id: 'mock-paid', order_no: 'TEST-PAID', customer_name: 'Dummy Paid', whatsapp: '81200000006', category: 'lainnya', deadline: 'besok', deadline_date: null, description: 'Dummy request untuk menguji status Paid.', status: 'paid', quote_amount: 500000, link: null, file_url: null },
]


export function formatRupiah(value) {
  if (value == null || Number.isNaN(Number(value))) return 'Rp 0'
  return 'Rp ' + Number(value).toLocaleString('id-ID')
}

export async function getPublicOrder(orderNo) {
  if (USE_MOCK_DATA) return MOCK_REQUESTS.find((r) => r.order_no.toLowerCase() === String(orderNo).toLowerCase()) || null
  const { data, error } = await supabase
    .from('requests')
    .select('*')
    .eq('order_no', orderNo)
    .maybeSingle()
  if (error) throw error
  return data
}

export async function createRequest(payload) {
  if (USE_MOCK_DATA) return { ...payload, id: `mock-${Date.now()}`, order_no: payload.order_no }
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
  if (USE_MOCK_DATA) return MOCK_REQUESTS.filter((r) => !filters.status || r.status === filters.status)
  let query = supabase.from('requests').select('*').order('created_at', { ascending: false })
  if (filters.status) query = query.eq('status', filters.status)
  const { data, error } = await query
  if (error) throw error
  return data
}

export async function getRequest(id) {
  if (USE_MOCK_DATA) return MOCK_REQUESTS.find((r) => r.id === id) || null
  const { data, error } = await supabase.from('requests').select('*').eq('id', id).maybeSingle()
  if (error) throw error
  return data
}

export async function updateRequest(id, patch) {
  if (USE_MOCK_DATA) { const item = MOCK_REQUESTS.find((r) => r.id === id); if (!item) throw new Error('Request tidak ditemukan'); Object.assign(item, patch); return item }
  const { data, error } = await supabase.from('requests').update(patch).eq('id', id).select().single()
  if (error) throw error
  return data
}

export async function listTransactions() {
  if (USE_MOCK_DATA) return MOCK_REQUESTS.filter((r) => ['done', 'paid'].includes(r.status)).map((r, i) => ({ id: `mock-trx-${i}`, transaction_no: `TRX-TEST-${i + 1}`, customer_name: r.customer_name, project_label: `${r.category} Project`, amount: r.quote_amount || 0, status: r.status === 'paid' ? 'paid' : 'pending', created_at: new Date().toISOString() }))
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
  new: 'New',
  consultation: 'Consultation',
  working: 'Working',
  review: 'Review',
  done: 'Done',
  paid: 'Paid',
}

export const DEADLINE_LABELS = {
  hari_ini: 'Hari Ini',
  besok: 'Besok',
  fleksibel: 'Fleksibel',
}