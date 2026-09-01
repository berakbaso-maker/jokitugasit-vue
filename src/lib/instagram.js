import { supabase } from './supabase'

export async function listInstagramLeads() {
  const { data, error } = await supabase
    .from('ig_leads')
    .select('*, requests(order_no,status)')
    .order('last_event_at', { ascending: false })
  if (error) throw error
  return data
}

export async function updateInstagramLead(id, patch) {
  const { data, error } = await supabase
    .from('ig_leads')
    .update({ ...patch, updated_at: new Date().toISOString() })
    .eq('id', id)
    .select()
    .single()
  if (error) throw error
  return data
}

export async function listInstagramPosts() {
  const { data, error } = await supabase.from('ig_posts').select('*').order('created_at', { ascending: false })
  if (error) throw error
  return data
}

export async function createInstagramPost(payload) {
  const { data, error } = await supabase.from('ig_posts').insert(payload).select().single()
  if (error) throw error
  return data
}

export async function listInstagramInsights() {
  const { data, error } = await supabase.from('ig_insights').select('*').order('snapshot_date', { ascending: false }).limit(30)
  if (error) throw error
  return data
}

export const IG_LEAD_STATUS = {
  new: 'Baru',
  contacted: 'Dihubungi',
  qualified: 'Potensial',
  converted: 'Jadi Request',
  ignored: 'Diabaikan',
}

export const IG_POST_STATUS = {
  draft: 'Draf',
  scheduled: 'Terjadwal',
  publishing: 'Dipublikasi',
  published: 'Tayang',
  failed: 'Gagal',
}
