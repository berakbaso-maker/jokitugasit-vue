<script setup>
import { computed, onMounted, ref } from 'vue'
import SideNav from '../components/SideNav.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import DataTable from '../components/ui/DataTable.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import StatusBadge from '../components/ui/StatusBadge.vue'
import KpiCard from '../components/ui/KpiCard.vue'
import { listPayments, listCommissions, verifyPayment, getReportsSummary } from '../lib/internal'
import { formatRupiah } from '../lib/api'

const loading = ref(true)
const error = ref('')
const payments = ref([])
const commissions = ref([])
const summary = ref(null)
const tab = ref('payments')
const busy = ref('')

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [p, c] = await Promise.all([listPayments(), listCommissions()])
    payments.value = p || []
    commissions.value = c || []
    try { summary.value = await getReportsSummary() } catch { summary.value = null }
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}
onMounted(load)

/* ---------------- Payments ---------------- */
const payCols = [
  { key: 'paid_at', label: 'Tanggal', sortable: true },
  { key: 'kind', label: 'Jenis', sortable: true },
  { key: 'amount', label: 'Jumlah', sortable: true, align: 'right' },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'method', label: 'Metode' },
  { key: 'actions', label: '', align: 'right', width: '110px' },
]

const payRows = computed(() => payments.value.map(p => ({
  ...p,
  paid_at: p.paid_at ? new Date(p.paid_at).toLocaleDateString('id-ID') : '—',
})))

const payStats = computed(() => {
  const conf = payments.value.filter(p => p.status === 'CONFIRMED' && p.kind !== 'REFUND')
  const pending = payments.value.filter(p => p.status === 'PENDING')
  const refunds = payments.value.filter(p => p.kind === 'REFUND')
  return {
    verified: conf.reduce((s, p) => s + Number(p.amount || 0), 0)
      - refunds.filter(r => r.status === 'CONFIRMED').reduce((s, r) => s + Number(r.amount || 0), 0),
    pending: pending.reduce((s, p) => s + Number(p.amount || 0), 0),
    pendingCount: pending.length,
    count: payments.value.length,
  }
})

/* ---------------- Commissions ---------------- */
const comCols = [
  { key: 'created_at', label: 'Dibuat', sortable: true },
  { key: 'eligible_amount', label: 'Dasar komisi', sortable: true, align: 'right' },
  { key: 'rate_pct', label: 'Rate', sortable: true, align: 'right' },
  { key: 'amount', label: 'Komisi', sortable: true, align: 'right' },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'actions', label: '', align: 'right', width: '110px' },
]

const comRows = computed(() => commissions.value.map(c => ({
  ...c,
  created_at: c.created_at ? new Date(c.created_at).toLocaleDateString('id-ID') : '—',
  rate_pct: c.rate_bps != null ? (c.rate_bps / 100).toFixed(1) + '%' : '—',
})))

const comStats = computed(() => {
  const sum = (st) => commissions.value
    .filter(c => st.includes(c.status))
    .reduce((s, c) => s + Number(c.amount || 0), 0)
  return {
    pending: sum(['PENDING', 'ELIGIBLE']),
    paid: sum(['PAID']),
    liability: sum(['PENDING', 'ELIGIBLE', 'ADJUSTMENT']),
  }
})

async function confirmPayment(p) {
  busy.value = p.id
  try {
    await verifyPayment(p.id)
    await load()
  } catch (e) {
    error.value = `Gagal verifikasi: ${e.message}`
  } finally {
    busy.value = ''
  }
}

function exportCsv() {
  const isPay = tab.value === 'payments'
  const data = isPay ? payments.value : commissions.value
  if (!data.length) return
  const cols = isPay
    ? ['id', 'kind', 'amount', 'status', 'method', 'paid_at', 'created_at']
    : ['id', 'eligible_amount', 'rate_bps', 'amount', 'status', 'paid_at', 'created_at']
  const lines = [cols.join(',')]
  for (const row of data) {
    lines.push(cols.map(c => {
      const v = row[c] ?? ''
      const s = String(v)
      return /[",\n]/.test(s) ? `"${s.replaceAll('"', '""')}"` : s
    }).join(','))
  }
  const blob = new Blob([lines.join('\n')], { type: 'text/csv;charset=utf-8' })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = isPay ? 'payments.csv' : 'commissions.csv'
  a.click()
  URL.revokeObjectURL(a.href)
}
</script>

<template>
  <SideNav>
    <PageHeader
      eyebrow="Modul 8"
      title="Payments & Commissions"
      description="Pendapatan terverifikasi, piutang, dan kewajiban komisi. Status invoice, pembayaran, dan komisi disimpan terpisah."
    >
      <template #actions>
        <button class="inline-flex items-center gap-2 border border-border-subtle bg-surface-white font-label-bold px-3.5 py-2.5 rounded-xl hover:bg-surface-container-low transition-colors" @click="exportCsv">
          <span class="material-symbols-outlined text-[18px]">download</span>
          Export CSV
        </button>
        <button class="inline-flex items-center gap-2 bg-primary text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-primary-container transition-colors" @click="load">
          <span class="material-symbols-outlined text-[18px]">refresh</span>
          Muat ulang
        </button>
      </template>
    </PageHeader>

    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <KpiCard label="Pendapatan terverifikasi" :value="payStats.verified" format="currency" icon="account_balance_wallet" tone="positive" :loading="loading" hint="CONFIRMED − refund" />
      <KpiCard label="Pembayaran tertunda" :value="payStats.pending" format="currency" icon="schedule" tone="warning" :loading="loading" :hint="`${payStats.pendingCount} menunggu verifikasi`" />
      <KpiCard label="Kewajiban komisi" :value="comStats.liability" format="currency" icon="pending_actions" tone="warning" :loading="loading" />
      <KpiCard label="Komisi dibayar" :value="comStats.paid" format="currency" icon="price_check" :loading="loading" />
    </div>

    <EmptyState v-if="error" tone="error" icon="database_off" title="Gagal memuat data"
                :description="error" action-label="Coba lagi" @action="load" />

    <template v-else>
      <div class="inline-flex rounded-xl border border-border-subtle overflow-hidden bg-surface-white mb-5">
        <button class="px-4 py-2.5 text-[13px] font-semibold"
                :class="tab === 'payments' ? 'bg-primary text-white' : 'text-secondary hover:bg-surface-container-low'"
                @click="tab = 'payments'">
          Pembayaran ({{ payments.length }})
        </button>
        <button class="px-4 py-2.5 text-[13px] font-semibold"
                :class="tab === 'commissions' ? 'bg-primary text-white' : 'text-secondary hover:bg-surface-container-low'"
                @click="tab = 'commissions'">
          Komisi ({{ commissions.length }})
        </button>
      </div>

      <DataTable v-if="tab === 'payments'" :columns="payCols" :rows="payRows" :loading="loading"
                 search-placeholder="Cari jenis, metode, status…"
                 empty-text="Belum ada pembayaran tercatat.">
        <template #cell-amount="{ row }">
          <span :class="row.kind === 'REFUND' ? 'text-on-error-container' : ''">
            {{ row.kind === 'REFUND' ? '−' : '' }}{{ formatRupiah(row.amount) }}
          </span>
        </template>
        <template #cell-status="{ row }"><StatusBadge :value="row.status" /></template>
        <template #cell-kind="{ row }"><StatusBadge :value="row.kind === 'DP' ? 'PENDING' : row.kind === 'SETTLEMENT' ? 'CONFIRMED' : 'VOID'" :label="row.kind" /></template>
        <template #cell-actions="{ row }">
          <button v-if="row.status === 'PENDING'"
                  class="text-[12px] font-semibold text-primary hover:underline disabled:opacity-40"
                  :disabled="busy === row.id" @click.stop="confirmPayment(row)">
            {{ busy === row.id ? '…' : 'Verifikasi' }}
          </button>
          <span v-else class="text-[12px] text-muted">—</span>
        </template>
      </DataTable>

      <DataTable v-else :columns="comCols" :rows="comRows" :loading="loading"
                 search-placeholder="Cari status komisi…"
                 empty-text="Belum ada komisi. Komisi hanya dibuat dari pembayaran terverifikasi.">
        <template #cell-eligible_amount="{ row }">{{ formatRupiah(row.eligible_amount) }}</template>
        <template #cell-amount="{ row }"><b>{{ formatRupiah(row.amount) }}</b></template>
        <template #cell-status="{ row }"><StatusBadge :value="row.status" /></template>
        <template #cell-actions="{ row }">
          <span class="text-[12px] text-muted">{{ row.paid_at ? new Date(row.paid_at).toLocaleDateString('id-ID') : '—' }}</span>
        </template>
      </DataTable>

      <p class="mt-4 text-[12px] text-muted leading-relaxed max-w-3xl">
        Nilai komisi dihitung di database: <code class="bg-surface-container px-1 rounded">amount = eligible_amount × rate_bps / 10000</code>.
        Komisi hanya dibuat dari pembayaran <b>CONFIRMED</b>, tidak pernah dari lead atau klik. Refund memicu penyesuaian ulang.
      </p>
    </template>
  </SideNav>
</template>
