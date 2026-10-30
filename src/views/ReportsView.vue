<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import KpiCard from '../components/ui/KpiCard.vue'
import TrendChart from '../components/ui/TrendChart.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import DataTable from '../components/ui/DataTable.vue'
import { getReportsSummary, getInternalTrends, getReportBreakdown } from '../lib/internal'
import { formatRupiah } from '../lib/api'

const loading = ref(true)
const error = ref('')
const summary = ref(null)
const trends = ref([])
const dim = ref('province')
const breakdown = ref([])
const days = ref(30)

const DIMS = [
  { key: 'province', label: 'Provinsi' },
  { key: 'university', label: 'Universitas' },
  { key: 'study_program', label: 'Program studi' },
  { key: 'source', label: 'Sumber lead' },
  { key: 'category', label: 'Kategori proyek' },
  { key: 'partner', label: 'Partner' },
]

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [s, t] = await Promise.all([
      getReportsSummary().catch(() => null),
      getInternalTrends(days.value).catch(() => []),
    ])
    summary.value = s
    trends.value = t || []
    await loadBreakdown()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

async function loadBreakdown() {
  try {
    breakdown.value = await getReportBreakdown(dim.value, days.value)
  } catch {
    breakdown.value = []
  }
}

onMounted(load)

const bdCols = computed(() => {
  const base = [{ key: 'label', label: DIMS.find(d => d.key === dim.value)?.label || 'Dimensi', sortable: true }]
  base.push({ key: 'leads', label: 'Lead', align: 'right', sortable: true })
  base.push({ key: 'projects', label: 'Proyek', align: 'right', sortable: true })
  base.push({ key: 'revenue', label: 'Pendapatan', align: 'right', sortable: true })
  return base
})

const bdRows = computed(() => breakdown.value.map(b => ({
  ...b,
  revenue: formatRupiah(b.revenue || 0),
})))

function exportCsv() {
  if (!breakdown.value.length) return
  const cols = ['label', 'leads', 'projects', 'revenue']
  const lines = [cols.join(',')]
  for (const row of breakdown.value) {
    lines.push(cols.map(c => {
      const s = String(row[c] ?? '')
      return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s
    }).join(','))
  }
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `report-${dim.value}.csv`
  a.click()
  URL.revokeObjectURL(a.href)
}

async function pickDim(k) {
  dim.value = k
  await loadBreakdown()
}
</script>

<template>
  <SideNav>
    <PageHeader
      eyebrow="Modul 10"
      title="Reports"
      description="Analitik dari data Supabase aktual — per kampanye, kampus, provinsi, program studi, sumber lead, kategori proyek, dan partner."
    >
      <template #actions>
        <select v-model.number="days" class="border border-border-subtle rounded-xl px-3 py-2.5 text-[13px] bg-surface-white" @change="load">
          <option :value="7">7 hari</option>
          <option :value="30">30 hari</option>
          <option :value="90">90 hari</option>
          <option :value="365">1 tahun</option>
        </select>
        <button class="inline-flex items-center gap-2 border border-border-subtle bg-surface-white font-label-bold px-3.5 py-2.5 rounded-xl hover:bg-surface-container-low transition-colors" @click="exportCsv">
          <span class="material-symbols-outlined text-[18px]">download</span>
          Export CSV
        </button>
      </template>
    </PageHeader>

    <EmptyState v-if="error" tone="error" icon="database_off" title="Gagal memuat laporan"
                :description="error" action-label="Coba lagi" @action="load" />

    <template v-else>
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <KpiCard label="Total lead" :value="summary?.total_leads" icon="groups" :loading="loading" />
        <KpiCard label="Lead terkualifikasi" :value="summary?.qualified_leads" icon="workspace_premium" tone="positive" :loading="loading" />
        <KpiCard label="Pendapatan terverifikasi" :value="summary?.verified_revenue" format="currency" icon="account_balance_wallet" tone="positive" :loading="loading" />
        <KpiCard label="Komisi tertunda" :value="summary?.pending_commissions" format="currency" icon="pending_actions" tone="warning" :loading="loading" />
      </div>

      <section class="bg-surface-white border border-border-subtle rounded-2xl p-5 shadow-card mb-6">
        <h2 class="font-bold text-[15px] mb-1">Tren {{ days }} hari</h2>
        <p class="text-[13px] text-muted mb-4">Lead baru dan pendapatan terverifikasi per hari.</p>
        <TrendChart :data="trends" :loading="loading" />
      </section>

      <section class="bg-surface-white border border-border-subtle rounded-2xl shadow-card overflow-hidden">
        <div class="px-5 pt-5 pb-3 flex flex-wrap items-center justify-between gap-3">
          <h2 class="font-bold text-[15px]">Rincian per dimensi</h2>
          <div class="flex flex-wrap gap-1.5">
            <button v-for="d in DIMS" :key="d.key"
                    class="px-2.5 py-1.5 rounded-lg text-[12px] font-semibold transition-colors"
                    :class="dim === d.key ? 'bg-accent-fill text-white' : 'bg-surface-container-low text-secondary hover:bg-surface-container'"
                    @click="pickDim(d.key)">
              {{ d.label }}
            </button>
          </div>
        </div>
        <DataTable :columns="bdCols" :rows="bdRows" :loading="loading"
                   search-placeholder="Cari…"
                   empty-text="Belum ada data untuk dimensi ini." />
      </section>
    </template>
  </SideNav>
</template>
