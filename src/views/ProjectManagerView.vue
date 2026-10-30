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
  listProjects, createProject, updateProject, deleteProject,
  listProjectTasks, createProjectTask, updateProjectTask, deleteProjectTask,
  PROJECT_STATUSES, PRIORITIES,
} from '../lib/internal'
import { formatRupiah } from '../lib/api'

const loading = ref(true)
const error = ref('')
const projects = ref([])
const view = ref('kanban')

const showForm = ref(false)
const saving = ref(false)
const formError = ref('')
const editing = ref(null)

const drawer = ref(false)
const active = ref(null)
const tasks = ref([])
const taskLoading = ref(false)
const newTask = ref('')

const blank = () => ({
  name: '', client_name: '', client_contact: '', category: '', scope: '',
  status: 'PLANNING', priority: 'MEDIUM', budget: '', start_date: '', due_date: '',
  progress_pct: 0, notes: '',
})
const form = ref(blank())

const KANBAN_COLS = PROJECT_STATUSES.map(s => ({
  key: s.key, label: s.label,
  dot: { INQUIRY: 'bg-surface-container', QUOTED: 'bg-primary-fixed', PLANNING: 'bg-primary-fixed',
    IN_PROGRESS: 'bg-indigo-500', REVIEW: 'bg-tertiary-fixed/40', DELIVERED: 'bg-success-green/10',
    CLOSED: 'bg-surface-container', CANCELLED: 'bg-error-container' }[s.key],
}))

const columns = [
  { key: 'name', label: 'Proyek', sortable: true },
  { key: 'client_name', label: 'Klien', sortable: true },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'progress_pct', label: 'Progres', sortable: true, align: 'right' },
  { key: 'budget', label: 'Nilai', sortable: true, align: 'right' },
  { key: 'due_date', label: 'Tenggat', sortable: true },
]

async function load() {
  loading.value = true
  error.value = ''
  try {
    projects.value = await listProjects()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
onMounted(load)

const stats = computed(() => {
  const activeSt = ['PLANNING', 'IN_PROGRESS', 'REVIEW']
  const act = projects.value.filter(p => activeSt.includes(p.status))
  const revenue = projects.value
    .filter(p => ['DELIVERED', 'CLOSED'].includes(p.status))
    .reduce((s, p) => s + Number(p.budget || 0), 0)
  const overdue = projects.value.filter(p =>
    p.due_date && p.status !== 'CLOSED' && p.status !== 'CANCELLED' &&
    new Date(p.due_date) < new Date() && p.status !== 'DELIVERED'
  ).length
  return { active: act.length, total: projects.value.length, revenue, overdue }
})

const tableRows = computed(() => projects.value.map(p => ({
  ...p,
  due_date: p.due_date ? new Date(p.due_date).toLocaleDateString('id-ID') : '—',
})))

function openCreate() {
  editing.value = null
  form.value = blank()
  formError.value = ''
  showForm.value = true
}

function openEdit(p) {
  editing.value = p
  formError.value = ''
  form.value = {
    ...blank(), ...p,
    budget: p.budget ?? '',
    start_date: p.start_date || '',
    due_date: p.due_date || '',
  }
  showForm.value = true
}

async function save() {
  formError.value = ''
  if (!form.value.name?.trim()) {
    formError.value = 'Nama proyek wajib diisi.'
    return
  }
  saving.value = true
  try {
    const payload = {
      ...form.value,
      budget: form.value.budget === '' ? null : Number(form.value.budget),
      progress_pct: Number(form.value.progress_pct) || 0,
      start_date: form.value.start_date || null,
      due_date: form.value.due_date || null,
    }
    if (editing.value) await updateProject(editing.value.id, payload)
    else await createProject(payload)
    showForm.value = false
    await load()
  } catch (e) {
    formError.value = e.message
  } finally {
    saving.value = false
  }
}

async function onMove({ item, to }) {
  const prev = projects.value.map(p => ({ ...p }))
  const i = projects.value.findIndex(p => p.id === item.id)
  if (i >= 0) projects.value[i] = { ...projects.value[i], status: to }
  try {
    await updateProject(item.id, { status: to })
  } catch (e) {
    projects.value = prev
    error.value = `Gagal memindahkan proyek: ${e.message}`
  }
}

async function openDetail(p) {
  active.value = p
  drawer.value = true
  taskLoading.value = true
  try {
    tasks.value = await listProjectTasks(p.id)
  } catch {
    tasks.value = []
  } finally {
    taskLoading.value = false
  }
}

async function addTask() {
  if (!newTask.value.trim() || !active.value) return
  try {
    const t = await createProjectTask({
      project_id: active.value.id, title: newTask.value.trim(), status: 'TODO',
    })
    tasks.value.push(t)
    newTask.value = ''
  } catch (e) {
    error.value = e.message
  }
}

async function toggleTask(t) {
  const next = t.status === 'DONE' ? 'TODO' : 'DONE'
  try {
    await updateProjectTask(t.id, { status: next })
    t.status = next
  } catch (e) {
    error.value = e.message
  }
}

async function removeTask(t) {
  try {
    await deleteProjectTask(t.id)
    tasks.value = tasks.value.filter(x => x.id !== t.id)
  } catch (e) {
    error.value = e.message
  }
}

async function setProgress(v) {
  if (!active.value) return
  const n = Math.max(0, Math.min(100, Number(v)))
  try {
    await updateProject(active.value.id, { progress_pct: n })
    active.value = { ...active.value, progress_pct: n }
    const i = projects.value.findIndex(p => p.id === active.value.id)
    if (i >= 0) projects.value[i] = { ...projects.value[i], progress_pct: n }
  } catch (e) {
    error.value = e.message
  }
}

async function removeProject() {
  if (!active.value) return
  if (!confirm(`Hapus proyek "${active.value.name}"? Semua task terkait ikut terhapus.`)) return
  try {
    await deleteProject(active.value.id)
    drawer.value = false
    active.value = null
    await load()
  } catch (e) {
    error.value = e.message
  }
}

const isOverdue = (p) => p.due_date && !['CLOSED', 'CANCELLED', 'DELIVERED'].includes(p.status)
  && new Date(p.due_date) < new Date()
</script>

<template>
  <SideNav>
    <PageHeader
      eyebrow="Modul 7"
      title="Project Manager"
      description="Kelola inquiry, penawaran, proyek klien, tenggat, task, dan progres. Terhubung ke lead, kampanye, dan partner."
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
          <span class="material-symbols-outlined text-[18px]">add</span>
          Proyek baru
        </button>
      </template>
    </PageHeader>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <KpiCard label="Proyek aktif" :value="stats.active" icon="folder_open" :loading="loading" />
      <KpiCard label="Total proyek" :value="stats.total" icon="inventory_2" :loading="loading" />
      <KpiCard label="Nilai terkirim" :value="stats.revenue" format="currency" icon="paid" tone="positive" :loading="loading" hint="Status DELIVERED/CLOSED" />
      <KpiCard label="Lewat tenggat" :value="stats.overdue" icon="running_with_errors" :tone="stats.overdue ? 'danger' : 'default'" :loading="loading" />
    </div>

    <EmptyState v-if="error" tone="error" icon="database_off" title="Gagal memuat proyek"
                :description="error" action-label="Coba lagi" @action="load" />

    <template v-else>
      <KanbanBoard
        v-if="view === 'kanban'" :columns="KANBAN_COLS" :items="projects"
        status-key="status" title-key="name" subtitle-key="client_name"
        @move="onMove" @open="openDetail"
      >
        <template #item-meta="{ item }">
          <StatusBadge :value="item.priority" />
          <span v-if="item.budget" class="text-[11px] text-muted">{{ formatRupiah(item.budget) }}</span>
          <span v-if="isOverdue(item)" class="text-[11px] text-on-error-container font-semibold">Lewat tenggat</span>
        </template>
      </KanbanBoard>

      <DataTable v-else :columns="columns" :rows="tableRows" :loading="loading"
                 search-placeholder="Cari proyek, klien…" empty-text="Belum ada proyek."
                 @row-click="openDetail">
        <template #cell-name="{ row }">
          <div class="font-medium">{{ row.name }}</div>
          <div v-if="row.category" class="text-[12px] text-muted">{{ row.category }}</div>
        </template>
        <template #cell-status="{ row }"><StatusBadge :value="row.status" /></template>
        <template #cell-progress_pct="{ row }">
          <div class="flex items-center gap-2 justify-end">
            <div class="w-16 h-1.5 bg-surface-container rounded-full overflow-hidden">
              <div class="h-full bg-primary rounded-full" :style="{ width: (row.progress_pct || 0) + '%' }" />
            </div>
            <span class="text-[12px] tabular-nums">{{ row.progress_pct || 0 }}%</span>
          </div>
        </template>
        <template #cell-budget="{ row }">{{ row.budget ? formatRupiah(row.budget) : '—' }}</template>
        <template #cell-due_date="{ row }">
          <span :class="isOverdue(row) ? 'text-on-error-container font-semibold' : ''">{{ row.due_date }}</span>
        </template>
      </DataTable>
    </template>

    <AppModal :open="showForm" :title="editing ? 'Edit proyek' : 'Proyek baru'" @close="showForm = false">
      <div class="grid sm:grid-cols-2 gap-4">
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Nama proyek *</span>
          <input v-model="form.name" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Nama klien</span>
          <input v-model="form.client_name" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Kontak klien</span>
          <input v-model="form.client_contact" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Kategori</span>
          <input v-model="form.category" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" placeholder="Web app, skripsi, debug…" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Nilai proyek (IDR)</span>
          <input v-model="form.budget" type="number" min="0" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Status</span>
          <select v-model="form.status" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]">
            <option v-for="s in PROJECT_STATUSES" :key="s.key" :value="s.key">{{ s.label }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Prioritas</span>
          <select v-model="form.priority" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]">
            <option v-for="p in PRIORITIES" :key="p" :value="p">{{ p }}</option>
          </select>
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Mulai</span>
          <input v-model="form.start_date" type="date" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block">
          <span class="text-[12px] font-semibold text-secondary">Tenggat</span>
          <input v-model="form.due_date" type="date" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
        <label class="block sm:col-span-2">
          <span class="text-[12px] font-semibold text-secondary">Lingkup pekerjaan</span>
          <textarea v-model="form.scope" rows="2" class="mt-1 w-full border border-border-subtle rounded-xl px-3 py-2 text-[14px]" />
        </label>
      </div>
      <p v-if="formError" class="mt-4 text-[13px] text-on-error-container bg-error-container border border-error/25 rounded-xl px-3 py-2">{{ formError }}</p>
      <template #footer>
        <div class="flex justify-end gap-2">
          <button class="px-4 py-2.5 rounded-xl border border-border-subtle font-label-bold hover:bg-surface-container-low" @click="showForm = false">Batal</button>
          <button class="px-4 py-2.5 rounded-xl bg-primary text-white font-label-bold hover:bg-primary-container disabled:opacity-50" :disabled="saving" @click="save">
            {{ saving ? 'Menyimpan…' : 'Simpan' }}
          </button>
        </div>
      </template>
    </AppModal>

    <DetailDrawer :open="drawer" :title="active?.name || ''" :subtitle="active?.client_name || ''" @close="drawer = false">
      <template v-if="active">
        <div class="flex items-center gap-2 mb-4 flex-wrap">
          <StatusBadge :value="active.status" size="md" />
          <StatusBadge :value="active.priority" size="md" />
          <span v-if="isOverdue(active)" class="text-[12px] text-on-error-container font-semibold">Lewat tenggat</span>
        </div>

        <div class="mb-5">
          <div class="flex items-center justify-between text-[12px] text-muted mb-1">
            <span>Progres</span><span class="tabular-nums font-semibold">{{ active.progress_pct || 0 }}%</span>
          </div>
          <div class="h-2 bg-surface-container rounded-full overflow-hidden mb-2">
            <div class="h-full bg-primary rounded-full transition-all" :style="{ width: (active.progress_pct || 0) + '%' }" />
          </div>
          <input type="range" min="0" max="100" step="5" :value="active.progress_pct || 0"
                 class="w-full accent-primary" @change="setProgress($event.target.value)" />
        </div>

        <dl class="grid grid-cols-2 gap-3 text-[13px] mb-5">
          <div><dt class="text-muted">Nilai</dt><dd class="font-medium">{{ active.budget ? formatRupiah(active.budget) : '—' }}</dd></div>
          <div><dt class="text-muted">Tenggat</dt><dd class="font-medium">{{ active.due_date || '—' }}</dd></div>
          <div><dt class="text-muted">Kategori</dt><dd class="font-medium">{{ active.category || '—' }}</dd></div>
          <div><dt class="text-muted">Kontak</dt><dd class="font-medium">{{ active.client_contact || '—' }}</dd></div>
        </dl>

        <div v-if="active.scope" class="mb-5 text-[13px] bg-surface-container-low rounded-xl p-3">{{ active.scope }}</div>

        <h3 class="font-bold text-[14px] mb-2">Task</h3>
        <div v-if="taskLoading" class="text-[13px] text-muted py-3">Memuat task…</div>
        <ul v-else class="space-y-1.5 mb-3">
          <li v-for="t in tasks" :key="t.id" class="flex items-center gap-2.5 group">
            <button class="w-4 h-4 rounded border-2 grid place-items-center shrink-0 transition-colors"
                    :class="t.status === 'DONE' ? 'bg-primary border-primary' : 'border-outline-variant hover:border-primary'"
                    @click="toggleTask(t)">
              <span v-if="t.status === 'DONE'" class="material-symbols-outlined text-[11px] text-white">check</span>
            </button>
            <span class="text-[13px] flex-1" :class="t.status === 'DONE' ? 'line-through text-muted' : ''">{{ t.title }}</span>
            <button class="opacity-0 group-hover:opacity-100 text-muted hover:text-on-error-container" @click="removeTask(t)">
              <span class="material-symbols-outlined text-[16px]">close</span>
            </button>
          </li>
          <li v-if="!tasks.length" class="text-[13px] text-muted">Belum ada task.</li>
        </ul>
        <div class="flex gap-2">
          <input v-model="newTask" placeholder="Task baru…" class="flex-1 border border-border-subtle rounded-xl px-3 py-2 text-[13px]" @keyup.enter="addTask" />
          <button class="px-3 py-2 rounded-xl bg-primary text-white text-[13px] font-semibold disabled:opacity-40" :disabled="!newTask.trim()" @click="addTask">Tambah</button>
        </div>
      </template>

      <template #footer>
        <div class="flex justify-between items-center">
          <button class="text-[13px] text-on-error-container font-semibold hover:underline" @click="removeProject">Hapus proyek</button>
          <button class="text-[13px] font-semibold text-primary hover:underline" @click="drawer = false; openEdit(active)">Edit proyek</button>
        </div>
      </template>
    </DetailDrawer>
  </SideNav>
</template>
