<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import {
  ACCOUNT_TYPE_LABELS,
  PERMISSION_BASIS_LABELS,
  PROSPECT_STATUS,
  isValidUsername,
  listOutreachQueue,
  listProspects,
  listTemplates,
  listTargetAccounts,
  logOutreach,
  normalizeUsername,
  renderTemplate,
} from '../lib/outreach'

const WEBSITE_URL = 'https://jokitugasit.my.id'

const tab = ref('queue') // 'queue' | 'all'
const loading = ref(true)
const saving = ref(false)
const error = ref('')
const notice = ref('')

const queue = ref([])
const allProspects = ref([])
const templates = ref([])
const accounts = ref([])

const search = ref('')
const campusFilter = ref('')
const statusFilter = ref('')

const selectedTemplateId = ref('')
const activeProspect = ref(null)
const dmNote = ref('')
const copied = ref(false)

const statusMeta = (s) => PROSPECT_STATUS[s] || PROSPECT_STATUS.NEW

const campuses = computed(() =>
  [...new Set([...queue.value, ...allProspects.value].map(p => p.campus).filter(Boolean))].sort()
)

const filteredQueue = computed(() => {
  const q = search.value.trim().toLowerCase()
  return queue.value.filter(p => {
    if (campusFilter.value && p.campus !== campusFilter.value) return false
    if (q && !String(p.ig_username).includes(q)
      && !String(p.display_name || '').toLowerCase().includes(q)) return false
    return true
  })
})

const filteredAll = computed(() => {
  const q = search.value.trim().toLowerCase()
  return allProspects.value.filter(p => {
    if (campusFilter.value && p.campus !== campusFilter.value) return false
    if (statusFilter.value && p.status !== statusFilter.value) return false
    if (q && !String(p.ig_username).includes(q)
      && !String(p.display_name || '').toLowerCase().includes(q)) return false
    return true
  })
})

const selectedTemplate = computed(() =>
  templates.value.find(t => t.id === selectedTemplateId.value) || templates.value[0] || null
)

const preview = computed(() => {
  if (!activeProspect.value || !selectedTemplate.value) return { text: '', missing: [], filled: [] }
  return renderTemplate(selectedTemplate.value.body, {
    prospect: activeProspect.value,
    websiteUrl: WEBSITE_URL,
  })
})

const stats = computed(() => {
  const all = allProspects.value
  return {
    queue: queue.value.length,
    contacted: all.filter(p => p.status === 'CONTACTED').length,
    interested: all.filter(p => ['INTERESTED_SERVICE', 'INTERESTED_REFERRAL'].includes(p.status)).length,
    dnc: all.filter(p => p.do_not_contact).length,
    converted: all.filter(p => p.status === 'CONVERTED').length,
  }
})

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [q, all, tpl, acc] = await Promise.all([
      listOutreachQueue(),
      listProspects(),
      listTemplates(),
      listTargetAccounts(),
    ])
    queue.value = q
    allProspects.value = all
    templates.value = tpl
    accounts.value = acc
    if (!selectedTemplateId.value && tpl.length) selectedTemplateId.value = tpl[0].id
  } catch (err) {
    error.value = err.message.includes('relation')
      ? 'Schema outreach belum dipasang. Jalankan supabase/migration-outreach-schema.sql.'
      : (err.message || 'Gagal memuat data outreach.')
  } finally {
    loading.value = false
  }
}

function openProspect(prospect) {
  activeProspect.value = prospect
  dmNote.value = ''
  copied.value = false
}

async function copyMessage() {
  if (!preview.value.text) return
  try {
    await navigator.clipboard.writeText(preview.value.text)
    copied.value = true
    setTimeout(() => (copied.value = false), 2500)
  } catch {
    error.value = 'Browser menolak akses clipboard. Salin manual dari panel preview.'
  }
}

function openInstagram(prospect) {
  const handle = normalizeUsername(prospect.ig_username)
  window.open(`https://instagram.com/${handle}/`, '_blank', 'noopener')
}

async function record(prospect, outcome) {
  if (!prospect) return
  if (outcome === 'DO_NOT_CONTACT'
    && !window.confirm(`Tandai @${prospect.ig_username} sebagai jangan-dihubungi? Prospek tidak akan muncul di antrean lagi.`)) {
    return
  }
  saving.value = true
  error.value = ''
  notice.value = ''
  try {
    await logOutreach({
      prospectId: prospect.id,
      templateId: selectedTemplate.value?.id || null,
      outcome,
      note: dmNote.value.trim() || null,
    })
    notice.value = `Tercatat: ${outcome.replaceAll('_', ' ').toLowerCase()} untuk @${prospect.ig_username}`
    activeProspect.value = null
    await load()
  } catch (err) {
    error.value = err.message || 'Gagal mencatat hasil kontak.'
  } finally {
    saving.value = false
  }
}

onMounted(load)
</script>

<template>
  <SideNav>
    <div class="flex flex-col lg:flex-row lg:items-end justify-between gap-4 mb-7">
      <div>
        <p class="text-label-sm text-electric-blue uppercase tracking-wider mb-2">Outreach</p>
        <h1 class="text-headline-lg font-bold">Antrean DM</h1>
        <p class="text-secondary mt-2 max-w-2xl">
          Salin pesan, buka profil, kirim manual dari aplikasi Instagram. Tidak ada pengiriman otomatis.
        </p>
      </div>
      <RouterLink to="/ops/prospects" class="inline-flex items-center gap-2 bg-electric-blue text-white font-label-bold px-5 py-2.5 rounded-xl hover:bg-primary transition-colors shadow-sm">
        <span class="material-symbols-outlined text-[20px]">person_add</span>
        Kelola Prospek
      </RouterLink>
    </div>

    <div v-if="error" class="mb-5 flex items-start gap-2 rounded-xl border border-urgency-red/30 bg-error-container p-4 text-on-error-container">
      <span class="material-symbols-outlined text-[18px]">error</span>
      <span class="text-sm">{{ error }}</span>
    </div>
    <div v-if="notice" class="mb-5 flex items-start gap-2 rounded-xl border border-success-green/30 bg-success-green/10 p-4 text-on-surface">
      <span class="material-symbols-outlined text-[18px] text-success-green">check_circle</span>
      <span class="text-sm">{{ notice }}</span>
    </div>

    <!-- Stats -->
    <div class="grid grid-cols-2 lg:grid-cols-5 gap-3 mb-7">
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Di Antrean</p>
        <p class="text-2xl font-bold">{{ stats.queue }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Sudah Dihubungi</p>
        <p class="text-2xl font-bold">{{ stats.contacted }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Berminat</p>
        <p class="text-2xl font-bold text-success-green">{{ stats.interested }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Jadi Klien</p>
        <p class="text-2xl font-bold text-electric-blue">{{ stats.converted }}</p>
      </div>
      <div class="bg-surface-white rounded-xl p-4 border border-border-subtle">
        <p class="text-label-sm text-on-surface-variant mb-1">Jangan Dihubungi</p>
        <p class="text-2xl font-bold text-on-surface-variant">{{ stats.dnc }}</p>
      </div>
    </div>

    <!-- Tabs + filters -->
    <div class="flex flex-col sm:flex-row sm:items-center gap-3 mb-5">
      <div class="flex gap-1 bg-surface-container p-1 rounded-xl w-fit">
        <button
          @click="tab = 'queue'"
          :class="tab === 'queue' ? 'bg-surface-white shadow text-on-surface' : 'text-on-surface-variant hover:text-on-surface'"
          class="px-5 py-2 rounded-lg font-bold text-sm transition-all">
          Antrean ({{ filteredQueue.length }})
        </button>
        <button
          @click="tab = 'all'"
          :class="tab === 'all' ? 'bg-surface-white shadow text-on-surface' : 'text-on-surface-variant hover:text-on-surface'"
          class="px-5 py-2 rounded-lg font-bold text-sm transition-all">
          Semua ({{ filteredAll.length }})
        </button>
      </div>

      <input
        v-model="search"
        type="search"
        placeholder="Cari username / nama..."
        class="flex-1 min-w-0 rounded-xl border border-outline-variant bg-surface-white px-4 py-2.5 text-sm focus:outline-none focus:ring-2 focus:ring-electric-blue/40"
      />

      <select v-model="campusFilter" class="rounded-xl border border-outline-variant bg-surface-white px-3 py-2.5 text-sm">
        <option value="">Semua Kampus</option>
        <option v-for="c in campuses" :key="c" :value="c">{{ c }}</option>
      </select>

      <select v-if="tab === 'all'" v-model="statusFilter" class="rounded-xl border border-outline-variant bg-surface-white px-3 py-2.5 text-sm">
        <option value="">Semua Status</option>
        <option v-for="(meta, key) in PROSPECT_STATUS" :key="key" :value="key">{{ meta.label }}</option>
      </select>
    </div>

    <div v-if="loading" class="text-center py-16 text-on-surface-variant">
      <span class="material-symbols-outlined text-[40px] animate-spin">progress_activity</span>
    </div>

    <div v-else class="grid lg:grid-cols-[1fr_400px] gap-6 items-start">
      <!-- List -->
      <div class="space-y-3">
        <div v-if="tab === 'queue' && filteredQueue.length === 0" class="text-center py-16 bg-surface-white rounded-xl border border-border-subtle">
          <span class="material-symbols-outlined text-[48px] mb-3 block text-on-surface-variant">inbox</span>
          <p class="font-bold">Antrean kosong.</p>
          <p class="text-sm text-on-surface-variant mt-1 max-w-md mx-auto">
            Tambahkan prospek manual atau impor CSV dari daftar yang diberikan admin angkatan.
          </p>
        </div>

        <div
          v-for="p in (tab === 'queue' ? filteredQueue : filteredAll)"
          :key="p.id"
          class="bg-surface-white rounded-xl border p-4 flex flex-col sm:flex-row sm:items-center justify-between gap-3 transition-colors cursor-pointer"
          :class="activeProspect?.id === p.id ? 'border-electric-blue ring-1 ring-electric-blue/30' : 'border-border-subtle hover:border-electric-blue/30'"
          @click="openProspect(p)"
        >
          <div class="min-w-0">
            <div class="flex items-center gap-2 flex-wrap">
              <p class="font-bold text-on-surface truncate">@{{ p.ig_username }}</p>
              <span :class="statusMeta(p.status).class" class="text-[11px] font-bold px-2 py-0.5 rounded-full">
                {{ statusMeta(p.status).label }}
              </span>
              <span v-if="p.do_not_contact" class="text-[11px] font-bold px-2 py-0.5 rounded-full bg-error-container text-on-error-container">
                DNC
              </span>
            </div>
            <p class="text-sm text-on-surface-variant mt-0.5 truncate">
              {{ p.display_name || 'Nama belum ada' }}
              <template v-if="p.campus">· {{ p.campus }}</template>
              <template v-if="p.cohort_year">· {{ p.cohort_year }}</template>
            </p>
            <p class="text-[11px] text-on-surface-variant mt-1">
              Sumber: {{ PERMISSION_BASIS_LABELS[p.permission_basis] || p.permission_basis }}
              <template v-if="p.target_accounts?.ig_username"> · dari @{{ p.target_accounts.ig_username }}</template>
            </p>
          </div>
          <div class="flex items-center gap-2 shrink-0">
            <button
              @click.stop="openProspect(p); openInstagram(p)"
              class="inline-flex items-center gap-1 text-xs font-bold px-3 py-1.5 rounded-lg bg-surface-container hover:bg-surface-container-high text-on-surface"
            >
              <span class="material-symbols-outlined text-[16px]">open_in_new</span>
              Profil
            </button>
          </div>
        </div>
      </div>

      <!-- Workspace -->
      <aside class="lg:sticky lg:top-6 bg-surface-white rounded-xl border border-border-subtle p-5">
        <template v-if="activeProspect">
          <div class="flex items-start justify-between gap-2 mb-4">
            <div class="min-w-0">
              <p class="font-bold truncate">@{{ activeProspect.ig_username }}</p>
              <p class="text-xs text-on-surface-variant truncate">
                {{ activeProspect.display_name || 'Nama belum ada' }}
              </p>
            </div>
            <button @click="activeProspect = null" class="text-on-surface-variant hover:text-on-surface">
              <span class="material-symbols-outlined text-[20px]">close</span>
            </button>
          </div>

          <label class="block text-label-sm text-on-surface-variant mb-1">Template DM</label>
          <select
            v-model="selectedTemplateId"
            class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-3 py-2.5 text-sm mb-4"
          >
            <option v-for="t in templates" :key="t.id" :value="t.id">{{ t.name }}</option>
          </select>

          <div v-if="preview.missing.length" class="mb-3 rounded-lg bg-amber-50 border border-amber-200 p-3 text-[11px] text-amber-800">
            Data belum tersedia untuk:
            <strong>{{ preview.missing.join(', ') }}</strong>.
            Placeholder dibiarkan terlihat — lengkapi data prospek dulu agar pesan tidak terkirim setengah jadi.
          </div>

          <div class="rounded-xl bg-surface-container-low border border-border-subtle p-3 max-h-64 overflow-y-auto">
            <p class="text-sm whitespace-pre-wrap leading-relaxed">{{ preview.text }}</p>
          </div>

          <p class="text-[11px] text-on-surface-variant mt-2">
            {{ preview.text.length }} karakter · periksa ulang sebelum mengirim
          </p>

          <div class="grid grid-cols-2 gap-2 mt-4">
            <button
              @click="copyMessage"
              class="inline-flex items-center justify-center gap-1.5 rounded-lg bg-electric-blue text-white font-bold text-sm py-2.5 hover:bg-primary transition-colors"
            >
              <span class="material-symbols-outlined text-[18px]">content_copy</span>
              {{ copied ? 'Tersalin!' : 'Salin Pesan' }}
            </button>
            <button
              @click="openInstagram(activeProspect)"
              class="inline-flex items-center justify-center gap-1.5 rounded-lg border border-electric-blue text-electric-blue font-bold text-sm py-2.5 hover:bg-surface-container-low transition-colors"
            >
              <span class="material-symbols-outlined text-[18px]">open_in_new</span>
              Buka IG
            </button>
          </div>

          <label class="block text-label-sm text-on-surface-variant mt-5 mb-1">Catatan respons (opsional)</label>
          <textarea
            v-model="dmNote"
            rows="2"
            placeholder="Mis. minta dikirim besok, sudah punya kode referral..."
            class="w-full rounded-xl border border-outline-variant bg-surface-container-low px-3 py-2 text-sm resize-none"
          ></textarea>

          <p class="text-label-sm text-on-surface-variant mt-4 mb-2">Catat hasil</p>
          <div class="grid grid-cols-2 gap-2">
            <button
              :disabled="saving"
              @click="record(activeProspect, 'SENT')"
              class="rounded-lg bg-surface-container hover:bg-surface-container-high font-bold text-xs py-2 disabled:opacity-50"
            >
              Sudah Dikirim
            </button>
            <button
              :disabled="saving"
              @click="record(activeProspect, 'REPLIED')"
              class="rounded-lg bg-surface-container hover:bg-surface-container-high font-bold text-xs py-2 disabled:opacity-50"
            >
              Membalas
            </button>
            <button
              :disabled="saving"
              @click="record(activeProspect, 'INTERESTED_SERVICE')"
              class="rounded-lg bg-success-green/15 text-success-green hover:bg-success-green/25 font-bold text-xs py-2 disabled:opacity-50"
            >
              Minat Jasa
            </button>
            <button
              :disabled="saving"
              @click="record(activeProspect, 'INTERESTED_REFERRAL')"
              class="rounded-lg bg-success-green/15 text-success-green hover:bg-success-green/25 font-bold text-xs py-2 disabled:opacity-50"
            >
              Minat Referral
            </button>
            <button
              :disabled="saving"
              @click="record(activeProspect, 'NOT_INTERESTED')"
              class="rounded-lg bg-surface-container hover:bg-surface-container-high font-bold text-xs py-2 disabled:opacity-50"
            >
              Tidak Minat
            </button>
            <button
              :disabled="saving"
              @click="record(activeProspect, 'DO_NOT_CONTACT')"
              class="rounded-lg bg-error-container text-on-error-container hover:bg-error-container/80 font-bold text-xs py-2 disabled:opacity-50"
            >
              Jangan Dihubungi
            </button>
          </div>
        </template>

        <div v-else class="text-center py-12 text-on-surface-variant">
          <span class="material-symbols-outlined text-[40px] mb-2 block">edit_note</span>
          <p class="text-sm">Pilih prospek untuk menyiapkan pesan.</p>
        </div>
      </aside>
    </div>
  </SideNav>
</template>
