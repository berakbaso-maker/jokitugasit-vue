<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import DataTable from '../components/ui/DataTable.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import StatusBadge from '../components/ui/StatusBadge.vue'
import KpiCard from '../components/ui/KpiCard.vue'
import DetailDrawer from '../components/ui/DetailDrawer.vue'
import {
  listWorkflowDefinitions, toggleWorkflow, listWorkflowRuns, listWorkflowLogs,
  runWorkflow, retryKey,
} from '../lib/internal'
import { pesanGalat } from '../lib/galat'

const loading = ref(true)
const error = ref('')
const workflows = ref([])
const runs = ref([])
const tab = ref('workflows')
const busy = ref('')

const drawer = ref(false)
const activeRun = ref(null)
const logs = ref([])
const logLoading = ref(false)

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [w, r] = await Promise.all([
      listWorkflowDefinitions().catch(() => []),
      listWorkflowRuns(50).catch(() => []),
    ])
    workflows.value = w || []
    runs.value = r || []
  } catch (e) {
    error.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  } finally {
    loading.value = false
  }
}
onMounted(load)

const stats = computed(() => ({
  total: workflows.value.length,
  enabled: workflows.value.filter(w => w.enabled).length,
  runs: runs.value.length,
  failed: runs.value.filter(r => r.status === 'FAILED').length,
}))

const wfCols = [
  { key: 'name', label: 'Workflow', sortable: true },
  { key: 'event_key', label: 'Event' },
  { key: 'enabled', label: 'Status', sortable: true },
  { key: 'max_attempts', label: 'Max retry', align: 'right' },
  { key: 'actions', label: '', align: 'right', width: '120px' },
]

const wfRows = computed(() => workflows.value.map(w => ({ ...w })))

const runCols = [
  { key: 'created_at', label: 'Waktu', sortable: true },
  { key: 'workflow', label: 'Workflow', sortable: true },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'attempts', label: 'Percobaan', align: 'right' },
  { key: 'duration', label: 'Durasi', align: 'right' },
]

const runRows = computed(() => runs.value.map(r => {
  let duration = '—'
  if (r.started_at && r.finished_at) {
    duration = `${Math.max(0, Math.round((new Date(r.finished_at) - new Date(r.started_at)) / 1000))} s`
  }
  return {
    ...r,
    created_at: r.created_at ? new Date(r.created_at).toLocaleString('id-ID') : '—',
    workflow: r.workflow_definitions?.name || r.event_key || '—',
    attempts: r.attempts ?? 0,
    duration,
  }
}))

async function toggle(w) {
  busy.value = w.id
  try {
    await toggleWorkflow(w.id, !w.enabled)
    w.enabled = !w.enabled
  } catch (e) {
    error.value = pesanGalat(e, 'Terjadi kesalahan. Coba lagi ya.')
  } finally {
    busy.value = ''
  }
}

async function retry(r) {
  busy.value = r.id
  try {
    await runWorkflow(r.event_key, retryKey(r.idempotency_key || r.id, (r.attempts || 0) + 1), r.payload || {})
    await load()
  } catch (e) {
    error.value = `Retry gagal: ${pesanGalat(e)}`
  } finally {
    busy.value = ''
  }
}

async function openRun(r) {
  activeRun.value = r
  drawer.value = true
  logLoading.value = true
  try {
    logs.value = await listWorkflowLogs(r.id)
  } catch {
    logs.value = []
  } finally {
    logLoading.value = false
  }
}
</script>

<template>
  <SideNav>
    <PageHeader
      eyebrow="Modul 9"
      title="Automation Center"
      description="Workflow berbasis event dengan riwayat eksekusi, retry, dan idempotency. Tidak ada otomasi pengiriman DM Instagram tanpa izin."
    >
      <template #actions>
        <button class="inline-flex items-center gap-2 border border-border-subtle bg-surface-white font-label-bold px-3.5 py-2.5 rounded-xl hover:bg-surface-container-low transition-colors" @click="load">
          <span class="material-symbols-outlined text-[18px]">refresh</span>
          Muat ulang
        </button>
      </template>
    </PageHeader>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <KpiCard label="Total workflow" :value="stats.total" icon="account_tree" :loading="loading" />
      <KpiCard label="Aktif" :value="stats.enabled" icon="toggle_on" tone="positive" :loading="loading" />
      <KpiCard label="Total run" :value="stats.runs" icon="history" :loading="loading" />
      <KpiCard label="Gagal" :value="stats.failed" icon="error" :tone="stats.failed ? 'danger' : 'default'" :loading="loading" />
    </div>

    <EmptyState v-if="error" tone="error" icon="database_off" title="Gagal memuat workflow"
                :description="error" action-label="Coba lagi" @action="load" />

    <template v-else>
      <div class="inline-flex rounded-xl border border-border-subtle overflow-hidden bg-surface-white mb-5">
        <button class="px-4 py-2.5 text-[13px] font-semibold"
                :class="tab === 'workflows' ? 'bg-accent-fill text-white' : 'text-secondary hover:bg-surface-container-low'"
                @click="tab = 'workflows'">
          Workflow ({{ workflows.length }})
        </button>
        <button class="px-4 py-2.5 text-[13px] font-semibold"
                :class="tab === 'runs' ? 'bg-accent-fill text-white' : 'text-secondary hover:bg-surface-container-low'"
                @click="tab = 'runs'">
          Riwayat eksekusi ({{ runs.length }})
        </button>
      </div>

      <DataTable v-if="tab === 'workflows'" :columns="wfCols" :rows="wfRows" :loading="loading"
                 search-placeholder="Cari workflow, event…"
                 empty-text="Belum ada workflow terdaftar. Jalankan migration untuk membuat workflow default.">
        <template #cell-name="{ row }">
          <div class="font-medium">{{ row.name }}</div>
          <div v-if="row.description" class="text-[12px] text-muted">{{ row.description }}</div>
        </template>
        <template #cell-event_key="{ row }">
          <code class="text-[12px] bg-surface-container px-1.5 py-0.5 rounded">{{ row.event_key }}</code>
        </template>
        <template #cell-enabled="{ row }">
          <button
            class="relative w-9 h-5 rounded-full transition-colors disabled:opacity-50"
            :class="row.enabled ? 'bg-accent-fill' : 'bg-surface-container'"
            :disabled="busy === row.id" @click.stop="toggle(row)"
          >
            <span class="absolute top-0.5 w-4 h-4 rounded-full bg-white transition-all"
                  :class="row.enabled ? 'left-[18px]' : 'left-0.5'" />
          </button>
        </template>
        <template #cell-actions="{ row }">
          <span class="text-[12px] text-muted">{{ row.enabled ? 'Aktif' : 'Nonaktif' }}</span>
        </template>
      </DataTable>

      <DataTable v-else :columns="runCols" :rows="runRows" :loading="loading"
                 search-placeholder="Cari workflow, status…"
                 empty-text="Belum ada eksekusi tercatat." @row-click="openRun">
        <template #cell-status="{ row }"><StatusBadge :value="row.status" /></template>
        <template #cell-duration="{ row }">
          <span class="tabular-nums">{{ row.duration }}</span>
        </template>
      </DataTable>
    </template>

    <DetailDrawer :open="drawer" :title="activeRun ? `Run ${activeRun.id.slice(0, 8)}` : ''"
                  :subtitle="activeRun?.status || ''" @close="drawer = false">
      <template v-if="activeRun">
        <dl class="grid grid-cols-2 gap-3 text-[13px] mb-5">
          <div><dt class="text-muted">Event</dt><dd class="font-medium">{{ activeRun.event_key || '—' }}</dd></div>
          <div><dt class="text-muted">Status</dt><dd><StatusBadge :value="activeRun.status" /></dd></div>
          <div><dt class="text-muted">Idempotency</dt><dd class="font-mono text-[11px] break-all">{{ activeRun.idempotency_key || '—' }}</dd></div>
          <div><dt class="text-muted">Percobaan</dt><dd class="font-medium">{{ activeRun.attempts ?? 0 }}</dd></div>
        </dl>

        <div v-if="activeRun.error" class="mb-4 text-[13px] bg-error-container border border-error/25 text-on-error-container rounded-xl p-3">
          {{ activeRun.error }}
        </div>

        <h3 class="font-bold text-[14px] mb-2">Log</h3>
        <div v-if="logLoading" class="text-[13px] text-muted">Memuat log…</div>
        <ul v-else-if="logs.length" class="space-y-2">
          <li v-for="l in logs" :key="l.id" class="text-[12px] flex gap-2">
            <span class="text-muted shrink-0 tabular-nums">{{ new Date(l.created_at).toLocaleTimeString('id-ID') }}</span>
            <span :class="l.level === 'ERROR' ? 'text-on-error-container' : 'text-on-surface'">{{ l.message }}</span>
          </li>
        </ul>
        <p v-else class="text-[13px] text-muted">Tidak ada log.</p>
      </template>

      <template #footer>
        <button v-if="activeRun && activeRun.status === 'FAILED'"
                class="text-[13px] font-semibold text-primary hover:underline disabled:opacity-40"
                :disabled="busy === activeRun.id" @click="retry(activeRun)">
          {{ busy === activeRun.id ? 'Menjalankan…' : 'Retry workflow' }}
        </button>
      </template>
    </DetailDrawer>
  </SideNav>
</template>
