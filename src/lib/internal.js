/**
 * lib/internal.js — akses data untuk platform internal.
 *
 * Semua fungsi memakai klien Supabase yang sudah ada dan RLS yang
 * sudah berlaku. Tidak ada kalkulasi uang di sisi klien yang ditulis
 * balik ke database: nilai uang selalu berasal dari RPC/server.
 *
 * Setiap fungsi melempar error asli Supabase supaya view bisa
 * menampilkan pesan migrasi yang tepat.
 */
import { supabase } from './supabase'

/* ------------------------------------------------------------------ */
/* Konstanta label — satu sumber untuk seluruh UI                      */
/* ------------------------------------------------------------------ */

export const LEAD_STAGES = [
  { key: 'NEW', label: 'Baru' },
  { key: 'RESEARCHING', label: 'Riset' },
  { key: 'ELIGIBLE_CONTACT', label: 'Kontak Layak' },
  { key: 'CONTACTED', label: 'Dihubungi' },
  { key: 'REPLIED', label: 'Membalas' },
  { key: 'INTERESTED', label: 'Tertarik' },
  { key: 'QUALIFIED', label: 'Kualifikasi' },
  { key: 'CLIENT', label: 'Klien' },
  { key: 'PARTNER', label: 'Partner' },
]

export const LEAD_CLOSED_STAGES = [
  { key: 'NOT_INTERESTED', label: 'Tidak Tertarik' },
  { key: 'DO_NOT_CONTACT', label: 'Jangan Dihubungi' },
  { key: 'CLOSED', label: 'Ditutup' },
]

export const LEAD_STAGE_LABEL = Object.fromEntries(
  [...LEAD_STAGES, ...LEAD_CLOSED_STAGES].map(s => [s.key, s.label])
)

export const CONSENT_LABEL = {
  UNKNOWN: 'Belum diketahui',
  REQUESTED: 'Diminta',
  GRANTED: 'Diberikan',
  DECLINED: 'Ditolak',
  WITHDRAWN: 'Dicabut',
}

export const PROVENANCE_LABEL = {
  MANUAL: 'Input manual',
  PUBLIC_DIRECTORY: 'Direktori publik',
  EVENT: 'Acara',
  REFERRAL: 'Referral',
  CSV_IMPORT: 'Import CSV',
  PARTNER: 'Partner',
}

export const COMMUNITY_TYPES = ['BEM', 'HMJ', 'HIMA', 'UKM', 'ANGKATAN', 'KOMUNITAS', 'LAINNYA']

export const PROJECT_STATUSES = [
  { key: 'INQUIRY', label: 'Inquiry' },
  { key: 'QUOTED', label: 'Penawaran' },
  { key: 'PLANNING', label: 'Perencanaan' },
  { key: 'IN_PROGRESS', label: 'Dikerjakan' },
  { key: 'REVIEW', label: 'Review' },
  { key: 'DELIVERED', label: 'Terkirim' },
  { key: 'CLOSED', label: 'Selesai' },
  { key: 'CANCELLED', label: 'Batal' },
]

export const PRIORITIES = ['LOW', 'MEDIUM', 'HIGH', 'URGENT']

/** Pesan bantuan kalau migrasi belum dijalankan. */
export const MIGRATION_HINT =
  'Tabel platform internal belum ada. Jalankan supabase/migration-internal-platform.sql di SQL Editor Supabase, lalu muat ulang halaman ini.'

function wrap(err) {
  const msg = String(err?.message || err || '')
  if (/does not exist|schema cache|relation .* not found/i.test(msg)) {
    const e = new Error(MIGRATION_HINT)
    e.cause = err
    throw e
  }
  throw err
}

async function run(promise) {
  try {
    const { data, error } = await promise
    if (error) throw error
    return data
  } catch (err) {
    wrap(err)
  }
}

/* ------------------------------------------------------------------ */
/* Overview                                                            */
/* ------------------------------------------------------------------ */

export async function getInternalOverview() {
  return run(supabase.rpc('get_internal_overview'))
}

export async function getInternalTrends(days = 30) {
  return run(supabase.rpc('get_internal_trends', { p_days: days }))
}

export async function getRecentActivity(limit = 12) {
  return run(supabase.rpc('get_recent_activity', { p_limit: limit }))
}

export async function getReportsSummary() {
  return run(supabase.rpc('get_reports_summary'))
}

export async function getReportBreakdown(dimension = 'province', days = 30) {
  return run(supabase.rpc('get_report_breakdown', { p_dimension: dimension, p_days: days }))
}

/* ------------------------------------------------------------------ */
/* Campuses                                                            */
/* ------------------------------------------------------------------ */

export async function listCampuses(filters = {}) {
  let q = supabase.from('campuses').select('*').order('created_at', { ascending: false })
  if (filters.province) q = q.eq('province', filters.province)
  if (filters.consent_status) q = q.eq('consent_status', filters.consent_status)
  if (filters.search) q = q.ilike('university', `%${filters.search}%`)
  return run(q)
}

export async function createCampus(payload) {
  const { data: auth } = await supabase.auth.getUser()
  return run(supabase.from('campuses').insert({
    ...payload,
    created_by: auth?.user?.id ?? null,
  }).select().single())
}

export async function updateCampus(id, patch) {
  return run(supabase.from('campuses').update(patch).eq('id', id).select().single())
}

export async function deleteCampus(id) {
  return run(supabase.from('campuses').delete().eq('id', id))
}

/** Import CSV kampus. Dedup ditangani unique constraint di DB. */
export async function importCampuses(rows) {
  if (!rows?.length) return { inserted: 0, skipped: 0 }
  const { data: auth } = await supabase.auth.getUser()
  const payload = rows.map(r => ({
    province: r.province,
    city: r.city || null,
    university: r.university,
    faculty: r.faculty || null,
    study_program: r.study_program || null,
    cohort_year: r.cohort_year ? Number(r.cohort_year) : null,
    community_name: r.community_name || null,
    community_type: r.community_type || null,
    authorized_contact_name: r.authorized_contact_name || null,
    authorized_contact_role: r.authorized_contact_role || null,
    consent_status: r.consent_status || 'UNKNOWN',
    provenance: r.provenance || 'CSV_IMPORT',
    provenance_ref: r.provenance_ref || null,
    tags: r.tags ? String(r.tags).split(',').map(t => t.trim()).filter(Boolean) : [],
    notes: r.notes || null,
    created_by: auth?.user?.id ?? null,
  }))
  // onConflict -> abaikan duplikat, jangan gagalkan seluruh batch
  const { data, error } = await supabase
    .from('campuses')
    .upsert(payload, {
      onConflict: 'university,faculty,study_program,cohort_year',
      ignoreDuplicates: true,
    })
    .select()
  if (error) wrap(error)
  return { inserted: data?.length ?? 0, skipped: payload.length - (data?.length ?? 0) }
}

/* ------------------------------------------------------------------ */
/* Leads                                                               */
/* ------------------------------------------------------------------ */

export async function listLeads(filters = {}) {
  let q = supabase.from('leads').select('*').order('created_at', { ascending: false })
  if (filters.stage) q = q.eq('stage', filters.stage)
  if (filters.source) q = q.eq('source', filters.source)
  if (filters.campaign_id) q = q.eq('campaign_id', filters.campaign_id)
  return run(q)
}

export async function createLead(payload) {
  const { data: auth } = await supabase.auth.getUser()
  const lead = await run(supabase.from('leads').insert({
    ...payload,
    owner_id: payload.owner_id ?? auth?.user?.id ?? null,
    created_by: auth?.user?.id ?? null,
  }).select().single())

  await run(supabase.from('lead_activities').insert({
    lead_id: lead.id,
    kind: 'SYSTEM',
    body: 'Lead dibuat',
    actor_id: auth?.user?.id ?? null,
  }))
  return lead
}

export async function updateLeadStage(leadId, fromStage, toStage) {
  const { data: auth } = await supabase.auth.getUser()
  const updated = await run(
    supabase.from('leads').update({ stage: toStage }).eq('id', leadId).select().single()
  )
  await run(supabase.from('lead_activities').insert({
    lead_id: leadId,
    kind: 'STAGE_CHANGE',
    from_stage: fromStage,
    to_stage: toStage,
    body: `${fromStage} → ${toStage}`,
    actor_id: auth?.user?.id ?? null,
  }))
  return updated
}

export async function updateLead(id, patch) {
  return run(supabase.from('leads').update(patch).eq('id', id).select().single())
}

export async function deleteLead(id) {
  return run(supabase.from('leads').delete().eq('id', id))
}

export async function listLeadActivities(leadId) {
  return run(
    supabase.from('lead_activities')
      .select('*')
      .eq('lead_id', leadId)
      .order('created_at', { ascending: false })
      .limit(50)
  )
}

export async function addLeadNote(leadId, body) {
  const { data: auth } = await supabase.auth.getUser()
  return run(supabase.from('lead_activities').insert({
    lead_id: leadId, kind: 'NOTE', body, actor_id: auth?.user?.id ?? null,
  }).select().single())
}

/** Deteksi duplikat berdasarkan dedupe_key (contact_ref + organization). */
export async function findDuplicateLeads(contactRef, organization) {
  const key = `${String(contactRef || '').toLowerCase()}|${String(organization || '').toLowerCase()}`
  return run(supabase.from('leads').select('id,display_name,organization,stage').eq('dedupe_key', key))
}

/* ------------------------------------------------------------------ */
/* Tasks                                                               */
/* ------------------------------------------------------------------ */

export async function listTasks(filters = {}) {
  let q = supabase.from('crm_tasks').select('*').order('due_at', { ascending: true, nullsFirst: false })
  if (filters.status) q = q.eq('status', filters.status)
  if (filters.openOnly) q = q.neq('status', 'DONE')
  return run(q)
}

export async function createTask(payload) {
  const { data: auth } = await supabase.auth.getUser()
  return run(supabase.from('crm_tasks').insert({
    ...payload, created_by: auth?.user?.id ?? null,
  }).select().single())
}

export async function updateTask(id, patch) {
  return run(supabase.from('crm_tasks').update(patch).eq('id', id).select().single())
}

/* ------------------------------------------------------------------ */
/* Projects                                                            */
/* ------------------------------------------------------------------ */

export async function listProjects(filters = {}) {
  let q = supabase.from('projects').select('*').order('created_at', { ascending: false })
  if (filters.status) q = q.eq('status', filters.status)
  return run(q)
}

export async function createProject(payload) {
  const { data: auth } = await supabase.auth.getUser()
  return run(supabase.from('projects').insert({
    ...payload,
    owner_id: payload.owner_id ?? auth?.user?.id ?? null,
    created_by: auth?.user?.id ?? null,
  }).select().single())
}

export async function updateProject(id, patch) {
  return run(supabase.from('projects').update(patch).eq('id', id).select().single())
}

export async function deleteProject(id) {
  return run(supabase.from('projects').delete().eq('id', id))
}

export async function listProjectTasks(projectId) {
  return run(supabase.from('project_tasks').select('*').eq('project_id', projectId).order('position'))
}

export async function createProjectTask(payload) {
  return run(supabase.from('project_tasks').insert(payload).select().single())
}

export async function updateProjectTask(id, patch) {
  return run(supabase.from('project_tasks').update(patch).eq('id', id).select().single())
}

export async function deleteProjectTask(id) {
  return run(supabase.from('project_tasks').delete().eq('id', id))
}

export async function listMilestones(projectId) {
  return run(supabase.from('project_milestones').select('*').eq('project_id', projectId).order('position'))
}

export async function createMilestone(payload) {
  return run(supabase.from('project_milestones').insert(payload).select().single())
}

/* ------------------------------------------------------------------ */
/* Referral attributions                                               */
/* ------------------------------------------------------------------ */

export async function listAttributions(partnerId = null) {
  let q = supabase.from('referral_attributions')
    .select('*, partners(full_name, referral_code)')
    .order('created_at', { ascending: false })
  if (partnerId) q = q.eq('partner_id', partnerId)
  return run(q)
}

/* ------------------------------------------------------------------ */
/* Payments & commissions                                              */
/* ------------------------------------------------------------------ */

export async function listPayments() {
  return run(supabase.from('payments').select('*').order('created_at', { ascending: false }))
}

export async function listCommissions() {
  return run(supabase.from('commissions').select('*').order('created_at', { ascending: false }))
}

/** Verifikasi pembayaran — hanya engineer (RLS + guard RPC di server). */
export async function verifyPayment(id) {
  return run(supabase.from('payments').update({ status: 'CONFIRMED' }).eq('id', id).select().single())
}

/* ------------------------------------------------------------------ */
/* Automation                                                          */
/* ------------------------------------------------------------------ */

export async function listWorkflowDefinitions() {
  return run(supabase.from('workflow_definitions').select('*').order('event_key'))
}

export async function toggleWorkflow(id, enabled) {
  return run(supabase.from('workflow_definitions').update({ enabled }).eq('id', id).select().single())
}

export async function listWorkflowRuns(limit = 100) {
  return run(
    supabase.from('workflow_runs').select('*').order('created_at', { ascending: false }).limit(limit)
  )
}

export async function listWorkflowLogs(runId) {
  return run(
    supabase.from('workflow_run_logs').select('*').eq('run_id', runId).order('created_at')
  )
}

/** Jalankan workflow — idempoten lewat idempotency_key. */
export async function runWorkflow(eventKey, idempotencyKey, payload = {}) {
  return run(supabase.rpc('run_workflow', {
    p_event_key: eventKey,
    p_idempotency_key: idempotencyKey,
    p_payload: payload,
  }))
}

/** Retry = jalankan ulang dengan kunci baru (attempt berikutnya). */
export function retryKey(baseKey, attempt) {
  return `${baseKey}#retry${attempt}`
}
