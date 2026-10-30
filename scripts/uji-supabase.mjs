// Uji end-to-end seluruh API Supabase yang dipakai aplikasi JokiTugasIT.
// Jalankan: ENGINEER_PASS="$(cat ~/.hermes/secrets/jokitugasit-engineer-pass.txt)" node scripts/uji-supabase.mjs
import fs from 'node:fs'
import { createClient } from '@supabase/supabase-js'

const env = Object.fromEntries(
  fs.readFileSync(new URL('../.env', import.meta.url), 'utf8')
    .split('\n').filter((l) => l.includes('=') && !l.startsWith('#'))
    .map((l) => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim()] })
)

const URL_SB = env.VITE_SUPABASE_URL
const KEY = env.VITE_SUPABASE_ANON_KEY
const EMAIL = 'engineer@jokitugasit.id'
const PASS = process.env.ENGINEER_PASS

if (!URL_SB || !KEY) throw new Error('.env tidak lengkap')
if (!PASS) throw new Error('ENGINEER_PASS belum di-set')

const anon = createClient(URL_SB, KEY, { auth: { persistSession: false } })
const eng = createClient(URL_SB, KEY, { auth: { persistSession: false } })

const hasil = []
const bersihkan = []
const catat = (tabel, id) => { if (id) bersihkan.push([tabel, id]) }
const harus = (syarat, pesan) => { if (!syarat) throw new Error(pesan) }
const ringkas = (v) => {
  const s = typeof v === 'string' ? v : JSON.stringify(v)
  return s && s.length > 90 ? s.slice(0, 90) + '…' : (s ?? 'null')
}

async function cek(grup, nama, fn) {
  try {
    const detail = await fn()
    hasil.push({ grup, nama, ok: true, detail: ringkas(detail) })
  } catch (e) {
    hasil.push({ grup, nama, ok: false, detail: ringkas(e.message || String(e)) })
  }
}

const hariIni = new Date().toISOString().slice(0, 10)
const kemarin = new Date(Date.now() - 30 * 864e5).toISOString().slice(0, 10)

// ───────────────────────── login engineer
let loginOk = false
{
  const { data, error } = await eng.auth.signInWithPassword({ email: EMAIL, password: PASS })
  loginOk = !error && Boolean(data.session)
  hasil.push({ grup: 'Auth', nama: 'login engineer', ok: loginOk, detail: error ? error.message : 'session ok' })
}

// ───────────────────────── PUBLIK (anon)
let orderUji = null
await cek('Publik', 'create_public_request (valid)', async () => {
  const { data, error } = await anon.rpc('create_public_request', {
    p_customer_name: 'Uji E2E', p_whatsapp: '81200000001',
    p_description: 'data uji otomatis, dihapus di akhir', p_category: 'web', p_deadline: 'besok',
    p_deadline_date: null, p_link: null, p_file_url: null, p_email: null,
    p_referral_code: null, p_campaign_code: null,
    p_utm_source: null, p_utm_medium: null, p_utm_campaign: null, p_utm_content: null, p_utm_term: null,
  })
  if (error) throw error
  harus(/^JT\d{6}$/.test(data), 'format order salah: ' + data)
  orderUji = data
  catat('requests', (await eng.from('requests').select('id').eq('order_no', data).single()).data.id)
  return data
})

await cek('Publik', 'track_request (valid, tanpa kolom internal)', async () => {
  const { data, error } = await anon.rpc('track_request', { p_order_no: orderUji })
  if (error) throw error
  harus(data.length === 1, 'harus 1 baris')
  const r = data[0]
  harus(r.order_no === orderUji, 'order_no beda')
  harus(!('whatsapp' in r) && !('internal_notes' in r) && !('email' in r), 'kolom internal bocor: ' + Object.keys(r))
  return Object.keys(r).join(',')
})

await cek('Publik', 'track_request (order tidak ada)', async () => {
  const { data, error } = await anon.rpc('track_request', { p_order_no: 'JT000000' })
  if (error) throw error
  harus(data.length === 0, 'harus kosong')
  return 'kosong'
})

await cek('Publik', 'create_public_request (kategori palsu ditolak)', async () => {
  const { error } = await anon.rpc('create_public_request', {
    p_customer_name: 'x', p_whatsapp: '1', p_description: 'x', p_category: 'pwned', p_deadline: 'besok',
  })
  harus(error && error.code === '22023', 'harus 22023, dapat: ' + (error && error.code))
  return error.code + ' ' + error.message
})

await cek('Publik', 'RLS: anon tidak bisa baca requests', async () => {
  const { data, error } = await anon.from('requests').select('*').limit(5)
  if (error) throw error
  harus(data.length === 0, 'anon melihat ' + data.length + ' baris')
  return '0 baris'
})

await cek('Publik', 'RLS: anon insert langsung ditolak', async () => {
  const { error } = await anon.from('requests').insert({
    order_no: 'JT111111', customer_name: 'x', whatsapp: '1', description: 'x',
    category: 'web', status: 'paid', quote_amount: 1,
  })
  harus(error, 'insert anon seharusnya ditolak')
  return error.code + ' ' + (error.message || '').slice(0, 40)
})

await cek('Publik', 'validate_referral_code (kode tidak ada)', async () => {
  const { data, error } = await anon.rpc('validate_referral_code', { p_code: 'TIDAKADA123' })
  if (error) throw error
  harus(data.length === 0, 'harus kosong')
  return 'kosong'
})

await cek('Publik', 'resolve_campaign (kode tidak ada)', async () => {
  const { data, error } = await anon.rpc('resolve_campaign', { p_code: 'TIDAKADA123' })
  if (error) throw error
  harus(data.length === 0, 'harus kosong')
  return 'kosong'
})

// ───────────────────────── ENGINEER
await cek('Engineer', 'list requests', async () => {
  const { data, error } = await eng.from('requests').select('*')
  if (error) throw error
  harus(data.some((r) => r.order_no === orderUji), 'request uji tidak terlihat engineer')
  return data.length + ' baris'
})

await cek('Engineer', 'update status request', async () => {
  const { data, error } = await eng.from('requests').update({ status: 'consultation' }).eq('order_no', orderUji).select('status').single()
  if (error) throw error
  harus(data.status === 'consultation', 'status tidak berubah')
  return data.status
})

await cek('Engineer', 'set quote_amount', async () => {
  const { data, error } = await eng.from('requests').update({ quote_amount: 150000 }).eq('order_no', orderUji).select('quote_amount').single()
  if (error) throw error
  harus(Number(data.quote_amount) === 150000, 'quote tidak tersimpan')
  return data.quote_amount
})

let paymentId = null
await cek('Engineer', 'record_payment', async () => {
  const { data: req } = await eng.from('requests').select('id').eq('order_no', orderUji).single()
  const { data, error } = await eng.rpc('record_payment', {
    p_request_id: req.id, p_kind: 'DP', p_amount: 50000,
    p_idempotency_key: 'uji-' + Date.now(), p_method: 'transfer', p_proof_url: null, p_paid_at: null, p_note: 'uji',
  })
  if (error) throw error
  paymentId = data.id
  catat('payments', data.id)
  return 'payment ' + data.id.slice(0, 8) + ' amount=' + data.amount
})

await cek('Engineer', 'void_payment', async () => {
  const { data, error } = await eng.rpc('void_payment', { p_payment_id: paymentId, p_reason: 'uji otomatis' })
  if (error) throw error
  return 'status=' + (data.status || JSON.stringify(data).slice(0, 40))
})

await cek('Engineer', 'get_analytics_overview', async () => {
  const { data, error } = await eng.rpc('analytics_overview', { p_from: kemarin, p_to: hariIni, p_campus: null })
  if (error) throw error
  harus(data !== null, 'null')
  return Object.keys(data).slice(0, 5).join(',')
})

await cek('Engineer', 'get_analytics_funnel', async () => {
  const { data, error } = await eng.rpc('analytics_funnel', { p_from: kemarin, p_to: hariIni, p_campus: null })
  if (error) throw error
  return data.length + ' stage'
})

await cek('Engineer', 'get_analytics_campuses', async () => {
  const { data, error } = await eng.rpc('analytics_campuses')
  if (error) throw error
  return data.length + ' kampus'
})

await cek('Engineer', 'get_analytics_campaigns', async () => {
  const { data, error } = await eng.rpc('analytics_campaigns', { p_from: kemarin, p_to: hariIni })
  if (error) throw error
  return data.length + ' campaign'
})

// ───────────────────────── PARTNER
let partnerCode = null
let partnerId = null
await cek('Partner', 'register_partner', async () => {
  const { data, error } = await anon.rpc('register_partner', {
    p_full_name: 'Uji Partner', p_whatsapp: '812' + String(Date.now()).slice(-8), p_campus: 'Kampus Uji', p_ewallet_info: '0812',
  })
  if (error) throw error
  partnerId = data[0].partner_id
  partnerCode = data[0].referral_code
  catat('partners', partnerId)
  return partnerCode
})

await cek('Partner', 'validate_referral_code (aktif)', async () => {
  const { data, error } = await anon.rpc('validate_referral_code', { p_code: partnerCode })
  if (error) throw error
  harus(data.length === 1 && data[0].valid === true, 'kode tidak valid')
  return data[0].display_name
})

await cek('Partner', 'partner_portal', async () => {
  const { data, error } = await anon.rpc('partner_portal', { p_code: partnerCode })
  if (error) throw error
  harus(data !== null, 'null')
  return Object.keys(data).slice(0, 6).join(',')
})

await cek('Partner', 'generate_referral_code', async () => {
  const { data, error } = await eng.rpc('generate_referral_code')
  if (error) throw error
  harus(typeof data === 'string' && data.length >= 4, 'kode aneh: ' + data)
  return data
})

await cek('Partner', 'rotate_partner_code', async () => {
  const { data, error } = await eng.rpc('rotate_partner_code', { p_partner_id: partnerId })
  if (error) throw error
  harus(data && data !== partnerCode, 'kode tidak berubah')
  partnerCode = data
  return data
})

await cek('Partner', 'request dengan referral_code → atribusi', async () => {
  const { data, error } = await anon.rpc('create_public_request', {
    p_customer_name: 'Uji Referral', p_whatsapp: '81200000003', p_description: 'uji atribusi',
    p_category: 'web', p_deadline: 'besok', p_referral_code: partnerCode,
  })
  if (error) throw error
  const { data: req } = await eng.from('requests').select('id').eq('order_no', data).single()
  catat('requests', req.id)
  // Jalur referral nyata: payment → recompute_commission → baris commissions untuk partner
  const pay = await eng.rpc('record_payment', {
    p_request_id: req.id, p_kind: 'DP', p_amount: 100000,
    p_idempotency_key: 'uji-ref-' + Date.now(), p_method: 'transfer', p_proof_url: null, p_paid_at: null, p_note: 'uji referral',
  })
  if (pay.error) throw pay.error
  catat('payments', pay.data.id)
  const kom = await eng.rpc('recompute_commission', { p_request_id: req.id })
  if (kom.error) throw kom.error
  const rows = Array.isArray(kom.data) ? kom.data : [kom.data]
  harus(rows[0] && rows[0].partner_id, 'komisi tidak terhubung ke partner')
  return data + ' → komisi partner ' + String(rows[0].partner_id).slice(0, 8) + ' status=' + rows[0].status
})

// ───────────────────────── CRM / OUTREACH
let prospectId = null
let templateId = null
let accountId = null
await cek('CRM', 'target_accounts insert', async () => {
  const { data, error } = await eng.from('target_accounts').insert({ ig_username: 'uji_akun_' + Date.now(), campus: 'Kampus Uji' }).select().single()
  if (error) throw error
  accountId = data.id
  catat('target_accounts', data.id)
  return data.ig_username
})

await cek('CRM', 'campuses insert', async () => {
  const { data, error } = await eng.from('campuses').insert({ province: 'DKI Jakarta', university: 'Universitas Uji ' + Date.now() }).select().single()
  if (error) throw error
  catat('campuses', data.id)
  return data.university
})

await cek('CRM', 'prospects insert', async () => {
  const { data, error } = await eng.from('prospects').insert({
    ig_username: 'uji_prospek_' + Date.now(), display_name: 'Uji Prospek',
    campus: 'Kampus Uji', permission_basis: 'MANUAL_ENTRY', source_account_id: accountId,
  }).select().single()
  if (error) throw error
  prospectId = data.id
  catat('prospects', data.id)
  return data.ig_username
})

await cek('CRM', 'prospects select + join target_accounts', async () => {
  const { data, error } = await eng.from('prospects').select('*, target_accounts(ig_username, campus)').eq('id', prospectId).single()
  if (error) throw error
  return 'ok keys=' + Object.keys(data).length
})

await cek('CRM', 'prospect_stats', async () => {
  const { data, error } = await eng.rpc('prospect_stats')
  if (error) throw error
  return JSON.stringify(data[0] ?? {}).slice(0, 60)
})

await cek('CRM', 'outreach_eligibility', async () => {
  const { data, error } = await eng.rpc('outreach_eligibility', { p_prospect_id: prospectId, p_channel: 'MANUAL_DM' })
  if (error) throw error
  return JSON.stringify(data[0] ?? {}).slice(0, 60)
})

await cek('CRM', 'dm_templates insert', async () => {
  const { data, error } = await eng.from('dm_templates').insert({ name: 'Uji ' + Date.now(), body: 'Halo {{username}}' }).select().single()
  if (error) throw error
  templateId = data.id
  catat('dm_templates', data.id)
  return data.name
})

await cek('CRM', 'log_outreach', async () => {
  const { error } = await eng.rpc('log_outreach', {
    p_prospect_id: prospectId, p_template_id: templateId, p_outcome: 'SENT', p_note: 'uji', p_channel: 'INSTAGRAM_DM_MANUAL',
  })
  if (error) throw error
  const { data, error: e2 } = await eng.from('outreach_logs').select('*').eq('prospect_id', prospectId)
  if (e2) throw e2
  harus(data.length >= 1, 'log tidak tersimpan')
  return data.length + ' log'
})

await cek('CRM', 'set_prospect_consent', async () => {
  const { data, error } = await eng.rpc('set_prospect_consent', { p_prospect_id: prospectId, p_status: 'OPTED_IN', p_source: 'MANUAL_CONTACT' })
  if (error) throw error
  return JSON.stringify(data).slice(0, 60)
})

await cek('CRM', 'clear_do_not_contact', async () => {
  const { error } = await eng.rpc('clear_do_not_contact', { p_prospect_id: prospectId, p_reason: 'uji' })
  if (error) throw error
  return 'ok'
})

await cek('CRM', 'import_prospects_batch', async () => {
  const rows = [
    { ig_username: 'uji_imp_' + Date.now() + 'a', display_name: 'Import A', campus: 'Kampus Uji' },
    { ig_username: 'uji_imp_' + Date.now() + 'b', display_name: 'Import B', campus: 'Kampus Uji' },
  ]
  const { data, error } = await eng.rpc('import_prospects_batch', {
    p_file_name: 'uji.csv', p_rows: rows, p_source_account: accountId,
    p_permission_basis: 'MANUAL_ENTRY', p_batch_id: null,
  })
  if (error) throw error
  const r = data[0]
  const { data: dibuat } = await eng.from('prospects').select('id').in('ig_username', rows.map((x) => x.ig_username))
  ;(dibuat || []).forEach((p) => catat('prospects', p.id))
  return 'inserted=' + r.inserted_count + ' duplikat=' + r.duplicate_in_file
})

await cek('CRM', 'create_request_from_prospect', async () => {
  const { data, error } = await eng.rpc('create_request_from_prospect', {
    p_prospect_id: prospectId, p_category: 'web', p_description: 'uji dari prospek', p_quote: 200000,
  })
  if (error) throw error
  const req = Array.isArray(data) ? data[0] : data
  catat('requests', req.id)
  return req.order_no
})

// ───────────────────────── INTERNAL PLATFORM
let projectId = null
await cek('Internal', 'projects insert', async () => {
  const { data, error } = await eng.from('projects').insert({ name: 'Proyek Uji ' + Date.now(), status: 'INQUIRY', client_name: 'Klien Uji' }).select().single()
  if (error) throw error
  projectId = data.id
  catat('projects', data.id)
  return data.name
})

await cek('Internal', 'project_tasks insert', async () => {
  const { data, error } = await eng.from('project_tasks').insert({ project_id: projectId, title: 'Tugas uji' }).select().single()
  if (error) throw error
  catat('project_tasks', data.id)
  return data.title
})

await cek('Internal', 'project_milestones insert', async () => {
  const { data, error } = await eng.from('project_milestones').insert({ project_id: projectId, title: 'Milestone uji', due_date: hariIni }).select().single()
  if (error) throw error
  catat('project_milestones', data.id)
  return data.title
})

let leadId = null
await cek('Internal', 'leads insert + activity', async () => {
  const { data, error } = await eng.from('leads').insert({ display_name: 'Lead Uji ' + Date.now(), stage: 'NEW', source: 'MANUAL' }).select().single()
  if (error) throw error
  leadId = data.id
  catat('leads', data.id)
  const { error: e2 } = await eng.from('lead_activities').insert({ lead_id: leadId, kind: 'NOTE', body: 'uji' })
  if (e2) throw e2
  const { error: e3 } = await eng.from('leads').update({ stage: 'CONTACTED' }).eq('id', leadId)
  if (e3) throw e3
  return 'lead + activity + stage change'
})

await cek('Internal', 'crm_tasks insert', async () => {
  const { data, error } = await eng.from('crm_tasks').insert({ title: 'Task uji', lead_id: leadId, due_at: new Date().toISOString() }).select().single()
  if (error) throw error
  catat('crm_tasks', data.id)
  return data.title
})

await cek('Internal', 'get_internal_overview', async () => {
  const { data, error } = await eng.rpc('get_internal_overview')
  if (error) throw error
  return Object.keys(data).slice(0, 6).join(',')
})

await cek('Internal', 'get_internal_trends', async () => {
  const { data, error } = await eng.rpc('get_internal_trends', { p_days: 30 })
  if (error) throw error
  return JSON.stringify(data).slice(0, 70)
})

await cek('Internal', 'get_recent_activity', async () => {
  const { data, error } = await eng.rpc('get_recent_activity', { p_limit: 10 })
  if (error) throw error
  return (Array.isArray(data) ? data.length : 0) + ' aktivitas'
})

await cek('Internal', 'get_reports_summary', async () => {
  const { data, error } = await eng.rpc('get_reports_summary')
  if (error) throw error
  return Object.keys(data).slice(0, 6).join(',')
})

await cek('Internal', 'get_report_breakdown', async () => {
  const { data, error } = await eng.rpc('get_report_breakdown', { p_dimension: 'province', p_days: 30 })
  if (error) throw error
  return data.length + ' baris'
})

// ───────────────────────── CAMPAIGN / WORKFLOW / IG
let campaignId = null
let workflowId = null
await cek('Campaign', 'campaigns insert', async () => {
  const { data, error } = await eng.from('campaigns').insert({
    name: 'Campaign Uji ' + Date.now(), objective: 'DIRECT_OUTREACH', channel: 'INSTAGRAM_MANUAL_DM', status: 'ACTIVE',
  }).select().single()
  if (error) throw error
  campaignId = data.id
  catat('campaigns', data.id)
  return data.code || data.name
})

await cek('Campaign', 'campaign_targets insert', async () => {
  const { data, error } = await eng.from('campaign_targets').insert({ campaign_id: campaignId, target_account_id: accountId }).select().single()
  if (error) throw error
  catat('campaign_targets', data.id)
  return 'ok'
})

await cek('Campaign', 'resolve_campaign (kode nyata)', async () => {
  const { data: c } = await eng.from('campaigns').select('code').eq('id', campaignId).single()
  const { data, error } = await anon.rpc('resolve_campaign', { p_code: c.code })
  if (error) throw error
  harus(data.length === 1, 'campaign tidak ketemu lewat kode')
  return data[0].name
})

await cek('Campaign', 'generate_campaign_code', async () => {
  const { data, error } = await eng.rpc('generate_campaign_code')
  if (error) throw error
  return data
})

await cek('Workflow', 'workflow_definitions insert + run_workflow', async () => {
  const key = 'uji_event_' + Date.now()
  const { data, error } = await eng.from('workflow_definitions').insert({ event_key: key, name: 'Workflow Uji', enabled: true }).select().single()
  if (error) throw error
  workflowId = data.id
  catat('workflow_definitions', data.id)
  const { data: run, error: e2 } = await eng.rpc('run_workflow', {
    p_event_key: key, p_idempotency_key: 'uji-' + Date.now(), p_payload: { uji: true },
  })
  if (e2) throw e2
  return JSON.stringify(run).slice(0, 70)
})

await cek('IG', 'ig_posts insert', async () => {
  const { data, error } = await eng.from('ig_posts').insert({ media_url: 'https://contoh.test/x.jpg', caption: 'uji', media_type: 'IMAGE', status: 'draft' }).select().single()
  if (error) throw error
  catat('ig_posts', data.id)
  return data.status
})

await cek('IG', 'ig_leads select (tabel ditulis webhook service_role)', async () => {
  const { data, error } = await eng.from('ig_leads').select('*').limit(1)
  if (error) throw error
  return data.length + ' baris terbaca'
})

await cek('IG', 'ig_insights select + import_batches select', async () => {
  const { error: e1 } = await eng.from('ig_insights').select('*').limit(1)
  if (e1) throw e1
  const { error: e2 } = await eng.from('import_batches').select('*').limit(1)
  if (e2) throw e2
  return 'kedua tabel terbaca'
})

// ───────────────────────── bersihkan
if (partnerId) {
  await eng.from('commissions').delete().eq('partner_id', partnerId)
  await eng.from('referral_attributions').delete().eq('partner_id', partnerId)
}
let terhapus = 0
for (const [tabel, id] of bersihkan.reverse()) {
  const { error } = await eng.from(tabel).delete().eq('id', id)
  if (!error) terhapus++
}
{
  const { data: anyar } = await eng.from('prospects').insert({
    ig_username: 'uji_hapus_' + Date.now(), display_name: 'Uji Hapus', campus: 'Kampus Uji',
    permission_basis: 'MANUAL_ENTRY',
  }).select().single()
  if (anyar) {
    const { error } = await eng.rpc('delete_prospect', { p_prospect_id: anyar.id, p_reason: 'uji selesai', p_suppress: false })
    hasil.push({ grup: 'CRM', nama: 'delete_prospect', ok: !error, detail: error ? error.message : 'prospek terhapus' })
  }
}

// ───────────────────────── ringkasan
const grupList = [...new Set(hasil.map((h) => h.grup))]
let gagal = 0
for (const g of grupList) {
  console.log('\n== ' + g + ' ==')
  for (const h of hasil.filter((x) => x.grup === g)) {
    if (!h.ok) gagal++
    console.log((h.ok ? '  PASS  ' : '  FAIL  ') + h.nama.padEnd(44) + ' ' + h.detail)
  }
}
console.log('\n=========================================')
console.log('total: ' + hasil.length + ' · lulus: ' + (hasil.length - gagal) + ' · gagal: ' + gagal)
console.log('baris uji dibersihkan: ' + terhapus + '/' + bersihkan.length)
process.exit(gagal === 0 ? 0 : 1)
