<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import {
  CAMPAIGN_CHANNELS,
  CAMPAIGN_OBJECTIVES,
  CAMPAIGN_STATUS,
  addCampaignTarget,
  createCampaign,
  formatRupiah,
  getAnalyticsCampaigns,
  listCampaignTargets,
  listCampaigns,
  updateCampaign,
  updateCampaignTarget,
} from '../lib/api'
import { listTargetAccounts } from '../lib/outreach'
import { downloadCsv, toCsv } from '../lib/csv'

const campaigns = ref([])
const analytics = ref([])
const targetAccounts = ref([])
const loading = ref(true)
const error = ref('')
const notice = ref('')

const showCreate = ref(false)
const saving = ref(false)
const formError = ref('')
const form = ref({
  name: '', objective: 'ADMIN_DISTRIBUTION', channel: 'INSTAGRAM_MANUAL_DM',
  campus: '', cohort_year: '', starts_on: '', ends_on: '',
  cost_rupiah: '', time_value_rupiah: '', notes: '',
})

const targetsFor = ref(null)
const targets = ref([])
const targetsLoading = ref(false)
const targetForm = ref({ target_account_id: '' })

const period = ref('all')
const PERIOD_OPTIONS = [
  { value: 'all', label: 'Semua waktu' },
  { value: '30d', label: '30 hari' },
  { value: 'month', label: 'Bulan ini' },
]

const METRIC_BY_ID = computed(() =>
  Object.fromEntries(analytics.value.map(row => [row.campaign_id, row]))
)

const totals = computed(() => {
  const rows = analytics.value
  return {
    campaigns: campaigns.value.length,
    active: campaigns.value.filter(c => c.status === 'ACTIVE').length,
    inquiries: rows.reduce((s, r) => s + Number(r.inquiries || 0), 0),
    paid: rows.reduce((s, r) => s + Number(r.paid_clients || 0), 0),
    gross: rows.reduce((s, r) => s + Number(r.gross || 0), 0),
  }
})

function periodRange() {
  if (period.value === 'all') return [null, null]
  const today = new Date()
  const iso = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  if (period.value === 'month') {
    return [iso(new Date(today.getFullYear(), today.getMonth(), 1)), iso(today)]
  }
  const from = new Date(today)
  from.setDate(from.getDate() - 29)
  return [iso(from), iso(today)]
}

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [from, to] = periodRange()
    const [list, rows, accs] = await Promise.all([
      listCampaigns(),
      getAnalyticsCampaigns(from, to),
      listTargetAccounts(),
    ])
    campaigns.value = list
    analytics.value = rows
    targetAccounts.value = accs
  } catch (err) {
    error.value = err.code === '42P01' || err.message?.includes('relation')
      ? 'Tabel campaign belum terpasang. Jalankan migration-consent-guard.sql lalu migration-campaigns.sql.'
      : (err.message || 'Gagal memuat campaign.')
  } finally {
    loading.value = false
  }
}

function openCreate() {
  form.value = {
    name: '', objective: 'ADMIN_DISTRIBUTION', channel: 'INSTAGRAM_MANUAL_DM',
    campus: '', cohort_year: '', starts_on: '', ends_on: '',
    cost_rupiah: '', time_value_rupiah: '', notes: '',
  }
  formError.value = ''
  showCreate.value = true
}

async function submitCreate() {
  formError.value = ''
  if (!form.value.name.trim()) {
    formError.value = 'Nama campaign wajib diisi.'
    return
  }

  saving.value = true
  try {
    const campaign = await createCampaign({
      name: form.value.name.trim(),
      objective: form.value.objective,
      channel: form.value.channel,
      campus: form.value.campus.trim() || null,
      cohort_year: form.value.cohort_year ? Number(form.value.cohort_year) : null,
      starts_on: form.value.starts_on || null,
      ends_on: form.value.ends_on || null,
      cost_rupiah: Math.max(0, Math.round(Number(form.value.cost_rupiah) || 0)),
      time_value_rupiah: Math.max(0, Math.round(Number(form.value.time_value_rupiah) || 0)),
      notes: form.value.notes.trim() || null,
    })
    showCreate.value = false
    notice.value = `Campaign "${campaign.name}" dibuat dengan kode ${campaign.code}.`
    await load()
  } catch (err) {
    formError.value = err.message || 'Gagal membuat campaign.'
  } finally {
    saving.value = false
  }
}

async function setStatus(campaign, status) {
  try {
    const updated = await updateCampaign(campaign.id, { status })
    Object.assign(campaign, updated)
    notice.value = `${campaign.name}: ${CAMPAIGN_STATUS[status] || status}.`
  } catch (err) {
    error.value = err.message || 'Gagal mengubah status campaign.'
  }
}

const MEDIUM = {
  INSTAGRAM_MANUAL_DM: 'instagram_dm',
  IG_STORY_PARTNER: 'instagram_story',
  WHATSAPP_REFERRAL: 'whatsapp',
  WEBSITE_OPT_IN: 'website',
}

function linkFor(campaign) {
  const origin = typeof window !== 'undefined' ? window.location.origin : 'https://jokitugasit.my.id'
  const params = new URLSearchParams({
    campaign: campaign.code,
    utm_source: 'instagram',
    utm_medium: MEDIUM[campaign.channel] || 'campaign',
    utm_campaign: campaign.code,
  })
  return `${origin}/request?${params.toString()}`
}

async function copyLink(campaign) {
  try {
    await navigator.clipboard.writeText(linkFor(campaign))
    notice.value = `Link campaign ${campaign.code} disalin.`
  } catch {
    error.value = 'Browser menolak akses clipboard.'
  }
}

async function openTargets(campaign) {
  targetsFor.value = campaign
  targets.value = []
  targetForm.value = { target_account_id: '' }
  targetsLoading.value = true
  try {
    targets.value = await listCampaignTargets(campaign.id)
  } catch (err) {
    error.value = err.message || 'Gagal memuat target campaign.'
  } finally {
    targetsLoading.value = false
  }
}

async function addTarget() {
  if (!targetForm.value.target_account_id) return
  try {
    const row = await addCampaignTarget({
      campaignId: targetsFor.value.id,
      targetAccountId: targetForm.value.target_account_id,
    })
    targets.value.push(row)
    targetForm.value = { target_account_id: '' }
    notice.value = 'Target ditambahkan ke campaign.'
  } catch (err) {
    error.value = err.code === '23505'
      ? 'Akun itu sudah ada di campaign ini.'
      : (err.message || 'Gagal menambah target.')
  }
}

async function setTargetStatus(row, status) {
  try {
    const updated = await updateCampaignTarget(row.id, { status })
    Object.assign(row, updated)
  } catch (err) {
    error.value = err.message || 'Gagal mengubah status target.'
  }
}

function exportCsv() {
  const rows = analytics.value.map(r => ({
    code: r.code,
    name: r.name,
    objective: r.objective,
    channel: r.channel,
    status: r.status,
    targets: r.targets,
    inquiries: r.inquiries,
    deals: r.deals,
    paid_clients: r.paid_clients,
    gross_rupiah: r.gross,
    commission_paid_rupiah: r.commission_paid,
    cost_rupiah: r.cost,
    cac_rupiah: r.cac ?? '',
  }))
  downloadCsv(
    `campaign-${new Date().toISOString().slice(0, 10)}.csv`,
    toCsv(rows, ['code', 'name', 'objective', 'channel', 'status', 'targets',
      'inquiries', 'deals', 'paid_clients', 'gross_rupiah',
      'commission_paid_rupiah', 'cost_rupiah', 'cac_rupiah']),
  )
}

onMounted(load)
</script>

<template>
  <SideNav>
    <div class="flex flex-col lg:flex-row lg:items-end justify-between gap-4 mb-7">
      <div>
        <p class="text-label-sm text-electric-blue uppercase tracking-wider mb-2">Distribusi</p>
        <h1 class="text-headline-lg font-bold">Kampanye</h1>
        <p class="text-secondary mt-2 max-w-2xl">
          Ukur penyebaran info lewat admin, DM manual, referral, dan inbound — tanpa blast otomatis.
        </p>
      </div>
      <div class="flex flex-wrap gap-2">
        <select v-model="period" @change="load" class="rounded-xl border border-outline-variant bg-surface-white px-3 py-2.5 text-sm">
          <option v-for="opt in PERIOD_OPTIONS" :key="opt.value" :value="opt.value">{{ opt.label }}</option>
        </select>
        <button @click="exportCsv" :disabled="analytics.length === 0" class="inline-flex items-center gap-2 rounded-xl border border-outline-variant px-4 py-2.5 text-sm font-bold hover:bg-surface-container-low disabled:opacity-50">
          <span class="material-symbols-outlined text-[18px]">download</span>
          Ekspor
        </button>
        <button @click="openCreate" class="inline-flex items-center gap-2 bg-electric-blue text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-primary transition-colors shadow-sm">
          <span class="material-symbols-outlined text-[20px]">add</span>
          Buat Campaign
        </button>
      </div>
    </div>

    <div v-if="error" class="mb-5 rounded-xl border border-urgency-red/30 bg-error-container p-4 text-sm text-on-error-container">{{ error }}</div>
    <div v-if="notice" class="mb-5 rounded-xl border border-success-green/30 bg-success-green/10 p-4 text-sm">{{ notice }}</div>

    <div class="grid grid-cols-2 lg:grid-cols-5 gap-3 mb-7">
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Campaign</p>
        <p class="text-2xl font-bold">{{ totals.campaigns }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Aktif</p>
        <p class="text-2xl font-bold text-success-green">{{ totals.active }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Inquiry</p>
        <p class="text-2xl font-bold">{{ totals.inquiries }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Klien Lunas</p>
        <p class="text-2xl font-bold text-electric-blue">{{ totals.paid }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Omzet</p>
        <p class="text-2xl font-bold">{{ formatRupiah(totals.gross) }}</p>
      </div>
    </div>

    <div v-if="loading" class="text-center py-16 text-on-surface-variant">
      <span class="material-symbols-outlined text-[40px] animate-spin">progress_activity</span>
    </div>

    <div v-else-if="campaigns.length === 0" class="text-center py-16 bg-surface-white rounded-xl border border-border-subtle">
      <span class="material-symbols-outlined text-[48px] mb-3 block text-on-surface-variant">campaign</span>
      <p class="font-bold">Belum ada campaign.</p>
      <p class="text-sm text-on-surface-variant mt-1">Mulai dari kampanye distribusi admin atau referral.</p>
    </div>

    <div v-else class="grid lg:grid-cols-2 gap-4">
      <div v-for="c in campaigns" :key="c.id" class="bg-surface-white rounded-xl border border-border-subtle p-5">
        <div class="flex items-start justify-between gap-3 mb-3">
          <div class="min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <p class="font-bold truncate">{{ c.name }}</p>
              <span class="text-[11px] font-bold px-2 py-0.5 rounded-full"
                :class="c.status === 'ACTIVE' ? 'bg-success-green/15 text-success-green' : c.status === 'PAUSED' ? 'bg-amber-100 text-amber-700' : 'bg-surface-container text-on-surface-variant'">
                {{ CAMPAIGN_STATUS[c.status] || c.status }}
              </span>
            </div>
            <p class="text-xs text-on-surface-variant mt-1 font-mono">{{ c.code }}</p>
            <p class="text-xs text-on-surface-variant mt-1">
              {{ CAMPAIGN_OBJECTIVES[c.objective] || c.objective }} ·
              {{ CAMPAIGN_CHANNELS[c.channel] || c.channel }}
              <template v-if="c.campus"> · {{ c.campus }}</template>
            </p>
          </div>
          <div class="text-right shrink-0 text-xs text-on-surface-variant">
            <p v-if="c.starts_on || c.ends_on">{{ c.starts_on || '—' }} → {{ c.ends_on || '—' }}</p>
            <p>Biaya {{ formatRupiah(c.cost_rupiah) }}</p>
          </div>
        </div>

        <div class="grid grid-cols-4 gap-2 text-center mb-3">
          <div class="rounded-lg bg-surface-container-low p-2">
            <p class="text-[10px] text-on-surface-variant">Inquiry</p>
            <p class="font-bold text-sm">{{ METRIC_BY_ID[c.id]?.inquiries ?? 0 }}</p>
          </div>
          <div class="rounded-lg bg-surface-container-low p-2">
            <p class="text-[10px] text-on-surface-variant">Deal</p>
            <p class="font-bold text-sm">{{ METRIC_BY_ID[c.id]?.deals ?? 0 }}</p>
          </div>
          <div class="rounded-lg bg-surface-container-low p-2">
            <p class="text-[10px] text-on-surface-variant">Lunas</p>
            <p class="font-bold text-sm">{{ METRIC_BY_ID[c.id]?.paid_clients ?? 0 }}</p>
          </div>
          <div class="rounded-lg bg-surface-container-low p-2">
            <p class="text-[10px] text-on-surface-variant">CAC</p>
            <p class="font-bold text-sm">{{ METRIC_BY_ID[c.id]?.cac == null ? '—' : formatRupiah(METRIC_BY_ID[c.id].cac) }}</p>
          </div>
        </div>

        <p v-if="METRIC_BY_ID[c.id]?.paid_clients < 5" class="text-[11px] text-amber-700 mb-3">
          Data masih kecil (&lt;5 klien lunas); persentase belum bisa disimpulkan.
        </p>

        <div class="flex flex-wrap gap-2">
          <button @click="copyLink(c)" class="text-xs font-bold px-3 py-1.5 rounded-lg bg-electric-blue text-white hover:bg-primary">
            Salin Link
          </button>
          <button @click="openTargets(c)" class="text-xs font-bold px-3 py-1.5 rounded-lg border border-outline-variant hover:bg-surface-container-low">
            Target ({{ METRIC_BY_ID[c.id]?.targets ?? 0 }})
          </button>
          <button v-if="c.status !== 'ACTIVE'" @click="setStatus(c, 'ACTIVE')" class="text-xs font-bold px-3 py-1.5 rounded-lg bg-success-green/15 text-success-green hover:bg-success-green/25">
            Aktifkan
          </button>
          <button v-if="c.status === 'ACTIVE'" @click="setStatus(c, 'PAUSED')" class="text-xs font-bold px-3 py-1.5 rounded-lg bg-amber-100 text-amber-700">
            Jeda
          </button>
          <button v-if="c.status !== 'COMPLETED'" @click="setStatus(c, 'COMPLETED')" class="text-xs font-bold px-3 py-1.5 rounded-lg border border-outline-variant text-on-surface-variant hover:bg-surface-container-low">
            Selesaikan
          </button>
        </div>
      </div>
    </div>

    <!-- Create modal -->
    <div v-if="showCreate" class="fixed inset-0 z-50 flex items-start justify-center bg-black/40 backdrop-blur-sm px-4 py-8 overflow-y-auto" @click.self="showCreate = false">
      <div class="bg-surface-white rounded-2xl shadow-2xl p-6 w-full max-w-lg">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-bold text-lg">Buat Campaign</h2>
          <button @click="showCreate = false" class="text-on-surface-variant hover:text-on-surface">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>
        <form @submit.prevent="submitCreate" class="space-y-3">
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Nama *</label>
            <input v-model="form.name" required class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm" placeholder="Admin HMIF 2023">
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Tujuan</label>
              <select v-model="form.objective" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-3 py-3 text-sm">
                <option v-for="(label, key) in CAMPAIGN_OBJECTIVES" :key="key" :value="key">{{ label }}</option>
              </select>
            </div>
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Channel</label>
              <select v-model="form.channel" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-3 py-3 text-sm">
                <option v-for="(label, key) in CAMPAIGN_CHANNELS" :key="key" :value="key">{{ label }}</option>
              </select>
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Kampus</label>
              <input v-model="form.campus" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Angkatan</label>
              <input v-model="form.cohort_year" type="number" min="1990" max="2036" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Mulai</label>
              <input v-model="form.starts_on" type="date" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Selesai</label>
              <input v-model="form.ends_on" type="date" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm">
            </div>
          </div>
          <div class="grid grid-cols-2 gap-3">
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Biaya nyata (Rp)</label>
              <input v-model="form.cost_rupiah" type="number" min="0" step="1" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm" placeholder="0">
            </div>
            <div>
              <label class="text-label-sm text-on-surface-variant block mb-1">Nilai waktu (Rp)</label>
              <input v-model="form.time_value_rupiah" type="number" min="0" step="1" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm" placeholder="0">
            </div>
          </div>
          <div>
            <label class="text-label-sm text-on-surface-variant block mb-1">Catatan</label>
            <textarea v-model="form.notes" rows="2" class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-4 py-3 text-sm"></textarea>
          </div>
          <p v-if="formError" class="text-sm text-urgency-red">{{ formError }}</p>
          <div class="flex gap-3 pt-1">
            <button type="button" @click="showCreate = false" class="flex-1 px-4 py-2.5 rounded-xl border border-outline-variant font-bold text-sm">Batal</button>
            <button type="submit" :disabled="saving" class="flex-1 px-4 py-2.5 rounded-xl bg-electric-blue text-white font-bold text-sm disabled:opacity-60">
              {{ saving ? 'Menyimpan...' : 'Simpan' }}
            </button>
          </div>
        </form>
      </div>
    </div>

    <!-- Targets modal -->
    <div v-if="targetsFor" class="fixed inset-0 z-50 flex items-start justify-center bg-black/40 backdrop-blur-sm px-4 py-8 overflow-y-auto" @click.self="targetsFor = null">
      <div class="bg-surface-white rounded-2xl shadow-2xl p-6 w-full max-w-lg">
        <div class="flex items-center justify-between mb-1">
          <h2 class="font-bold text-lg">Target Campaign</h2>
          <button @click="targetsFor = null" class="text-on-surface-variant hover:text-on-surface">
            <span class="material-symbols-outlined">close</span>
          </button>
        </div>
        <p class="text-xs text-on-surface-variant mb-4">{{ targetsFor.name }} · {{ targetsFor.code }}</p>

        <div class="flex gap-2 mb-4">
          <select v-model="targetForm.target_account_id" class="flex-1 rounded-xl border border-outline-variant bg-surface-container-low px-3 py-2.5 text-sm">
            <option value="">Pilih akun target…</option>
            <option v-for="a in targetAccounts" :key="a.id" :value="a.id">@{{ a.ig_username }} — {{ a.campus || 'tanpa kampus' }}</option>
          </select>
          <button @click="addTarget" :disabled="!targetForm.target_account_id" class="px-4 py-2.5 rounded-xl bg-electric-blue text-white font-bold text-sm disabled:opacity-50">Tambah</button>
        </div>

        <div v-if="targetsLoading" class="text-center py-6 text-sm text-on-surface-variant">Memuat…</div>
        <div v-else-if="targets.length === 0" class="text-center py-6 text-sm text-on-surface-variant">Belum ada target.</div>
        <ul v-else class="divide-y divide-border-subtle">
          <li v-for="t in targets" :key="t.id" class="py-2 flex items-center justify-between gap-2">
            <div class="min-w-0">
              <p class="text-sm font-bold truncate">@{{ t.target_accounts?.ig_username || '—' }}</p>
              <p class="text-[11px] text-on-surface-variant">{{ t.target_accounts?.campus || '—' }}</p>
            </div>
            <select :value="t.status" @change="setTargetStatus(t, $event.target.value)" class="rounded-lg border border-outline-variant bg-surface-white px-2 py-1 text-[11px]">
              <option value="PLANNED">Direncanakan</option>
              <option value="CONTACTED">Dihubungi</option>
              <option value="PERMISSION_GRANTED">Izin diberikan</option>
              <option value="DECLINED">Menolak</option>
              <option value="CONVERTED">Jadi klien</option>
            </select>
          </li>
        </ul>
      </div>
    </div>
  </SideNav>
</template>
