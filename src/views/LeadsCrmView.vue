<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import DataTable from '../components/ui/DataTable.vue'
import KanbanBoard from '../components/ui/KanbanBoard.vue'
import AppModal from '../components/ui/AppModal.vue'
import DetailDrawer from '../components/ui/DetailDrawer.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import StatusBadge from '../components/ui/StatusBadge.vue'
import KpiCard from '../components/ui/KpiCard.vue'
import {
  listLeads, createLead, updateLead, updateLeadStage, deleteLead,
  listLeadActivities, addLeadNote, findDuplicateLeads,
  LEAD_STAGES, LEAD_CLOSED_STAGES, LEAD_STAGE_LABEL,
} from '../lib/internal'

const loading = ref(true)
const error = ref('')
const leads = ref([])
const view = ref('kanban') // kanban | table

const showForm = ref(false)
const saving = ref(false)
const formError = ref('')
const duplicate = ref(null)

const drawer = ref(false)
const active = ref(null)
const activities = ref([])
const noteText = ref('')
const activityLoading = ref(false)

const blank = () => ({
  display_name: '', organization: '', role_title: '', contact_ref: '',
  source: 'MANUAL', stage: 'NEW', priority: 'MEDIUM', notes: '',
  email: '', phone: '', campus_id: '',
})
const form = ref(blank())

const columns = [
  { key: 'display_name', label: 'Nama', sortable: true },
  { key: 'organization', label: 'Organisasi', sortable: true },
  { key: 'stage', label: 'Tahap', sortable: true },
  { key: 'priority', label: 'Prioritas', sortable: true },
  { key: 'contact_ref', label: 'Kontak' },
  { key: 'created_at', label: 'Dibuat', sortable: true },
]

const KANBAN_COLS = LEAD_STAGES.map(s => ({
  key: s.key, label: s.label,
  dot: { NEW: 'bg-surface-container', RESEARCHING: 'bg-surface-container', ELIGIBLE_CONTACT: 'bg-primary-fixed',
    CONTACTED: 'bg-primary-fixed', REPLIED: 'bg-secondary-container', INTERESTED: 'bg-secondary-container',
    QUALIFIED: 'bg-success-green/10', CLIENT: 'bg-success-green/10', PARTNER: 'bg-success-green/10' }[s.key],
}))

async function load() {
  loading.value = true
  error.value = ''
  try {
    leads.value = await listLeads()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
onMounted(load)

const stats = computed(() => {
  const q = leads.value.filter(l => ['QUALIFIED', 'CLIENT', 'PARTNER'].includes(l.stage)).length
  const active = leads.value.filter(l => ![...LEAD_CLOSED_STAGES.map(s => s.key), 'CLIENT', 'PARTNER'].includes(l.stage)).length
  return { total: leads.value.length, qualified: q, active, closed: leads.value.length - active }
})

const tableRows = computed(() => leads.value.map(l => ({
  ...l,
  created_at: l.created_at ? new Date(l.created_at).toLocaleDateString('id-ID') : '—',
})))

function openCreate() {
  form.value = blank()
  formError.value = ''
  duplicate.value = null
  showForm.value = true
}

async function save() {
  formError.value = ''
  duplicate.value = null
  if (!form.value.display_name?.trim()) {
    formError.value = 'Nama lead wajib diisi.'
    return
  }
  saving.value = true
  try {
    // Cek duplikat sebelum insert
    if (form.value.contact_ref || form.value.organization) {
      const dups = await findDuplicateLeads(form.value.contact_ref, form.value.organization)
      if (dups?.length) {
        duplicate.value = dups
        saving.value = false
        return
      }
    }
    await createLead({
      ...form.value,
      campus_id: form.value.campus_id || null,
    })
    showForm.value = false
    await load()
  } catch (e) {
    formError.value = e.message
  } finally {
    saving.value = false
  }
}

async function onMove({ item, to }) {
  const prev = leads.value.map(l => ({ ...l }))
  // optimistic
  const idx = leads.value.findIndex(l => l.id === item.id)
  if (idx >= 0) leads.value[idx] = { ...leads.value[idx], stage: to }
  try {
    await updateLeadStage(item.id, item.stage, to)
  } catch (e) {
    leads.value = prev
    error.value = `Gagal memindahkan lead: ${e.message}`
  }
}

async function openDetail(lead) {
  active.value = lead
  drawer.value = true
  activityLoading.value = true
  noteText.value = ''
  try {
    activities.value = await listLeadActivities(lead.id)
  } catch (e) {
    activities.value = []
  } finally {
    activityLoading.value = false
  }
}

async function changeStage(stage) {
  if (!active.value || active.value.stage === stage) return
  try {
    const updated = await updateLeadStage(active.value.id, active.value.stage, stage)
    active.value = updated
    const i = leads.value.findIndex(l => l.id === updated.id)
    if (i >= 0) leads.value[i] = updated
    activities.value = await listLeadActivities(updated.id)
  } catch (e) {
    error.value = e.message
  }
}

async function saveNote() {
  if (!noteText.value.trim() || !active.value) return
  try {
    await addLeadNote(active.value.id, noteText.value.trim())
    noteText.value = ''
    activities.value = await listLeadActivities(active.value.id)
  } catch (e) {
    error.value = e.message
  }
}

async function removeLead() {
  if (!active.value) return
  if (!confirm(`Hapus lead "${active.value.display_name}"? Tindakan tercatat di audit log.`)) return
  try {
    await deleteLead(active.value.id)
    drawer.value = false
    active.value = null
    await load()
  } catch (e) {
    error.value = e.message
  }
}

function relTime(iso) {
  if (!iso) return ''
  const m = Math.floor((Date.now() - new Date(iso).getTime()) / 60000)
  if (m < 1) return 'baru saja'
  if (m < 60) return `${m} mnt lalu`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h} jam lalu`
  return `${Math.floor(h / 24)} hari lalu`
}
</script>

<template>
  <SideNav>
    <PageHeader
      eyebrow="Modul 5"
      title="Leads CRM"
      description="Pipeline penjualan dan status kelayakan kontak disimpan terpisah — status sales tidak pernah dianggap sebagai izin menghubungi."
    >
      <template #actions>
        <div class="inline-flex rounded-xl border border-border-subtle overflow-hidden bg-surface-white">
          <button class="px-3 py-2 text-[13px] font-semibold inline-flex items-center gap-1.5"
                  :class="view === 'kanban' ? 'bg-primary text-white' : 'text-secondary'" @click="view = 'kanban'">
            <span class="material-symbols-outlined text-[16px]">view_kanban</span> Kanban
          </button>
          <button class="px-3 py-2 text-[13px] font-semibold inline-flex items-center gap-1.5"
                  :class="view === 'table' ? 'bg-primary text-white' : 'text-secondary'" @click="view = 'table'">
            <span class="material-symbols-outlined text-[16px]">table_rows</span> Tabel
          </button>
        </div>
        <button class="inline-flex items-center gap-2 bg-primary text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-primary-container transition-colors" @click="openCreate">
          <span class="material-symbols-outlined text-[18px]">person_add</span>
          Lead baru
        </button>
      </template>
    </PageHeader>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <KpiCard label="Total lead" :value="stats.total" icon="groups" :loading="loading" />
      <KpiCard label="Pipeline aktif" :value="stats.active" icon="trending_up" :loading="loading" />
      <KpiCard label="Kualifikasi+" :value="stats.qualified" icon="workspace_premium" tone="positive" :loading="loading" />
      <KpiCard label="Ditutup / DNC" :value="stats.closed" icon="block" :loading="loading" />
    </div>

    <EmptyState
      v-if="error" tone="error" icon="database_off" title="Gagal memuat lead"
      :description="error" action-label="Coba lagi" @action="load"
    />

    <template v-else>
      <KanbanBoard
        v-if="view === 'kanban'"
        :columns="KANBAN_COLS" :items="leads" status-key="stage"
        title-key="display_name" subtitle-key="organization"
        @move="onMove" @open="openDetail"
      >
        <template #item-meta="{ item }">
          <StatusBadge :value="item.priority" />
          <span v-if="item.contact_ref" class="text-[11px] text-muted truncate">{{ item.contact_ref }}</span>
        </template>
      </KanbanBoard>

      <DataTable
        v-else
        :columns="columns" :rows="tableRows" :loading="loading"
        search-placeholder="Cari nama, organisasi, kontak…"
        empty-text="Belum ada lead."
        @row-click="openDetail"
      >
        <template #cell-display_name="{ row }">
          <div class="font-medium">{{ row.display_name }}</div>
          <div v-if="row.role_title" class="text-[12px] text-muted">{{ row.role_title }}</div>
        </template>
        <template #cell-stage="{ row }">
          <StatusBadge :value="row.stage" :label="LEAD_STAGE_LABEL[row.stage]" />
        </template>
        <template #cell-priority="{ row }"><StatusBadge :value="row.priority" /></template>
      </DataTable>

      <!-- Closed stages summary -->
      <section v-if="view === 'kanban'" class="mt-6 bg-surface-white border border-border-subtle rounded-2xl p-5 shadow-card">
        <h2 class="font-bold text-[15px] mb-3">Status penutupan</h2>
        <div class="flex flex-wrap gap-2">
          <div v-for="s in LEAD_CLOSED_STAGES" :key="s.key"
               class="flex items-center gap-2 px-3 py-2 rounded-xl bg-surface-container-low">
            <StatusBadge :value="s.key" :label="s.label" />
            <span class="text-[13px] font-semibold tabular-nums">
              {{ leads.filter(l => l.stage === s.key).length }}
            </span>
          </div>
        </div>
      </section>
    </template>

    <!-- Create modal -->
    <AppModal :open="showForm" title="Lead baru" subtitle="Pipeline sales terpisah dari izin menghubungi." @close="showForm = false">
      <div class="grid sm:grid-cols-2 gap-4">
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Nama / nama akun *</span>
          <input v-model="form.display_name" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Organisasi / kampus</span>
          <input v-model="form.organization" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Jabatan</span>
          <input v-model="form.role_title" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Kontak (IG / WA / email)</span>
          <input v-model="form.contact_ref" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="@username" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Sumber</span>
          <select v-model="form.source" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]">
            <option value="MANUAL">Manual</option>
            <option value="INBOUND_FORM">Form inbound</option>
            <option value="REFERRAL">Referral</option>
            <option value="INSTAGRAM">Instagram</option>
            <option value="CAMPAIGN">Kampanye</option>
            <option value="CAMPUS_EVENT">Acara kampus</option>
            <option value="PARTNER">Partner</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Tahap awal</span>
          <select v-model="form.stage" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]">
            <option v-for="s in LEAD_STAGES" :key="s.key" :value="s.key">{{ s.label }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Prioritas</span>
          <select v-model="form.priority" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]">
            <option value="LOW">Rendah</option>
            <option value="MEDIUM">Sedang</option>
            <option value="HIGH">Tinggi</option>
            <option value="URGENT">Mendesak</option>
          </select>
        </label>
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Catatan</span>
          <textarea v-model="form.notes" rows="2" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
      </div>

      <div v-if="duplicate" class="mt-4 bg-tertiary-fixed/40 border border-tertiary/20 rounded-xl px-4 py-3 text-[13px] text-tertiary">
        <p class="font-semibold mb-1">Kemungkinan duplikat ditemukan:</p>
        <ul class="list-disc pl-4">
          <li v-for="d in duplicate" :key="d.id">{{ d.display_name }} — {{ d.organization }} ({{ LEAD_STAGE_LABEL[d.stage] }})</li>
        </ul>
        <p class="mt-2">Ubah kontak/organisasi, atau simpan tetap sebagai lead terpisah.</p>
      </div>

      <p v-if="formError" class="mt-4 text-[13px] text-on-error-container bg-error-container border border-error/25 rounded-xl px-3 py-2">{{ formError }}</p>

      <template #footer>
        <div class="flex justify-end gap-2">
          <button class="px-4 py-2.5 rounded-xl border border-border-subtle font-label-bold hover:bg-surface-container-low" @click="showForm = false">Batal</button>
          <button class="px-4 py-2.5 rounded-xl bg-primary text-white font-label-bold hover:bg-primary-container disabled:opacity-50" :disabled="saving" @click="save">
            {{ saving ? 'Menyimpan…' : (duplicate ? 'Simpan tetap' : 'Simpan') }}
          </button>
        </div>
      </template>
    </AppModal>

    <!-- Detail drawer -->
    <DetailDrawer
      :open="drawer" :title="active?.display_name || ''"
      :subtitle="active?.organization || ''" @close="drawer = false"
    >
      <template v-if="active">
        <div class="flex items-center gap-2 mb-4">
          <StatusBadge :value="active.stage" :label="LEAD_STAGE_LABEL[active.stage]" size="md" />
          <StatusBadge :value="active.priority" size="md" />
        </div>

        <label class="block mb-4">
          <span class="text-[12px] font-semibold text-secondary">Ubah tahap</span>
          <select
            class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]"
            :value="active.stage" @change="changeStage($event.target.value)"
          >
            <option v-for="s in [...LEAD_STAGES, ...LEAD_CLOSED_STAGES]" :key="s.key" :value="s.key">{{ s.label }}</option>
          </select>
        </label>

        <dl class="grid grid-cols-2 gap-3 text-[13px] mb-5">
          <div><dt class="text-muted">Kontak</dt><dd class="font-medium">{{ active.contact_ref || '—' }}</dd></div>
          <div><dt class="text-muted">Sumber</dt><dd class="font-medium">{{ active.source || '—' }}</dd></div>
          <div><dt class="text-muted">Jabatan</dt><dd class="font-medium">{{ active.role_title || '—' }}</dd></div>
          <div><dt class="text-muted">Dibuat</dt><dd class="font-medium">{{ active.created_at ? new Date(active.created_at).toLocaleDateString('id-ID') : '—' }}</dd></div>
        </dl>

        <div v-if="active.notes" class="mb-5 text-[13px] bg-surface-container-low rounded-xl p-3">
          {{ active.notes }}
        </div>

        <h3 class="font-bold text-[14px] mb-2">Riwayat</h3>
        <div v-if="activityLoading" class="text-[13px] text-muted py-3">Memuat riwayat…</div>
        <ul v-else-if="activities.length" class="space-y-2.5 mb-4">
          <li v-for="a in activities" :key="a.id" class="flex gap-2.5">
            <span class="w-1.5 h-1.5 rounded-full bg-primary mt-2 shrink-0" />
            <div class="min-w-0">
              <p class="text-[13px]">
                <template v-if="a.kind === 'STAGE_CHANGE'">
                  Tahap: <b>{{ LEAD_STAGE_LABEL[a.from_stage] || a.from_stage }}</b> → <b>{{ LEAD_STAGE_LABEL[a.to_stage] || a.to_stage }}</b>
                </template>
                <template v-else>{{ a.body }}</template>
              </p>
              <p class="text-[11px] text-muted">{{ relTime(a.created_at) }}</p>
            </div>
          </li>
        </ul>
        <p v-else class="text-[13px] text-muted mb-4">Belum ada riwayat.</p>

        <div class="flex gap-2">
          <input
            v-model="noteText" placeholder="Tambah catatan…"
            class="flex-1 border border-border-subtle rounded-xl px-3 py-2 text-[13px]"
            @keyup.enter="saveNote"
          />
          <button class="px-3 py-2 rounded-xl bg-primary text-white text-[13px] font-semibold disabled:opacity-40"
                  :disabled="!noteText.trim()" @click="saveNote">Kirim</button>
        </div>
      </template>

      <template #footer>
        <button class="text-[13px] text-on-error-container font-semibold hover:underline" @click="removeLead">Hapus lead</button>
      </template>
    </DetailDrawer>
  </SideNav>
</template>
