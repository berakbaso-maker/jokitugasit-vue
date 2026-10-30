<script setup>
import { computed, onMounted, ref } from 'vue'
import { RouterLink } from 'vue-router'
import SideNav from '../components/SideNav.vue'
import PageHeader from '../components/ui/PageHeader.vue'
import KpiCard from '../components/ui/KpiCard.vue'
import TrendChart from '../components/ui/TrendChart.vue'
import StatusBadge from '../components/ui/StatusBadge.vue'
import EmptyState from '../components/ui/EmptyState.vue'
import {
  getInternalOverview, getInternalTrends, getRecentActivity,
  listTasks, updateTask, LEAD_STAGE_LABEL,
} from '../lib/internal'
import { formatRupiah } from '../lib/api'

const loading = ref(true)
const error = ref('')
const kpi = ref(null)
const trends = ref([])
const activity = ref([])
const tasks = ref([])
const period = ref(30)

const PERIODS = [
  { value: 7, label: '7 hari' },
  { value: 30, label: '30 hari' },
  { value: 90, label: '90 hari' },
]

async function load() {
  loading.value = true
  error.value = ''
  try {
    const [o, t, a, tk] = await Promise.all([
      getInternalOverview(),
      getInternalTrends(period.value),
      getRecentActivity(10),
      listTasks({ openOnly: true }),
    ])
    kpi.value = o
    trends.value = Array.isArray(t) ? t : []
    activity.value = Array.isArray(a) ? a : []
    tasks.value = tk || []
  } catch (e) {
    error.value = e.message || 'Gagal memuat data.'
  } finally {
    loading.value = false
  }
}

onMounted(load)

const dueTasks = computed(() => {
  const now = Date.now()
  return tasks.value
    .filter(t => t.status !== 'DONE')
    .sort((a, b) => {
      const av = a.due_at ? new Date(a.due_at).getTime() : Infinity
      const bv = b.due_at ? new Date(b.due_at).getTime() : Infinity
      return av - bv
    })
    .slice(0, 6)
    .map(t => {
      const due = t.due_at ? new Date(t.due_at).getTime() : null
      return {
        ...t,
        overdue: due !== null && due < now,
        dueLabel: t.due_at
          ? new Date(t.due_at).toLocaleDateString('id-ID', { day: '2-digit', month: 'short' })
          : 'Tanpa tenggat',
      }
    })
})

const alerts = computed(() => {
  const out = []
  if (!kpi.value) return out
  if (kpi.value.failed_workflows > 0) {
    out.push({
      tone: 'error', icon: 'error',
      title: `${kpi.value.failed_workflows} workflow gagal`,
      body: 'Periksa Automation Center untuk melihat error dan menjalankan ulang.',
      to: '/internal/automation',
    })
  }
  const overdue = dueTasks.value.filter(t => t.overdue).length
  if (overdue > 0) {
    out.push({
      tone: 'warning', icon: 'schedule',
      title: `${overdue} task melewati tenggat`,
      body: 'Tindak lanjuti task yang sudah lewat waktu.',
      to: '/internal/leads',
    })
  }
  if (kpi.value.pending_commissions > 0) {
    out.push({
      tone: 'warning', icon: 'payments',
      title: 'Komisi menunggu persetujuan',
      body: `${formatRupiah(kpi.value.pending_commissions)} belum dibayarkan.`,
      to: '/internal/payments',
    })
  }
  return out
})

async function completeTask(t) {
  await updateTask(t.id, { status: 'DONE' })
  tasks.value = tasks.value.filter(x => x.id !== t.id)
}

const actIcon = (k) => ({
  lead: 'person_add', project: 'folder', payment: 'payments',
  workflow: 'bolt', lead_activity: 'chat',
}[k] || 'history')

function relTime(iso) {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const m = Math.floor(diff / 60000)
  if (m < 1) return 'baru saja'
  if (m < 60) return `${m} menit lalu`
  const h = Math.floor(m / 60)
  if (h < 24) return `${h} jam lalu`
  return `${Math.floor(h / 24)} hari lalu`
}
</script>

<template>
  <SideNav>
    <PageHeader
      eyebrow="Internal"
      title="Overview"
      description="Ringkasan operasional bisnis. Semua angka diambil langsung dari Supabase — tidak ada nilai yang dikarang."
    >
      <template #actions>
        <div class="inline-flex rounded-xl border border-border-subtle overflow-hidden bg-surface-white">
          <button
            v-for="p in PERIODS" :key="p.value"
            class="px-3 py-2 text-[13px] font-semibold transition-colors"
            :class="period === p.value ? 'bg-primary text-white' : 'text-secondary hover:bg-surface-container-low'"
            @click="period = p.value; load()"
          >{{ p.label }}</button>
        </div>
        <button
          class="inline-flex items-center gap-2 bg-primary text-white font-label-bold px-4 py-2.5 rounded-xl hover:bg-primary-container transition-colors"
          @click="load"
        >
          <span class="material-symbols-outlined text-[18px]">refresh</span>
          Muat ulang
        </button>
      </template>
    </PageHeader>

    <EmptyState
      v-if="error"
      tone="error" icon="database_off" title="Data belum tersedia"
      :description="error" action-label="Coba lagi" @action="load"
    />

    <template v-else>
      <!-- KPI grid -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <KpiCard label="Total Kampus" :value="kpi?.total_campuses" icon="school" :loading="loading" hint="Komunitas kampus terdaftar" />
        <KpiCard label="Prospek Opt-in" :value="kpi?.opted_in_prospects" icon="verified_user" :loading="loading" hint="Boleh dihubungi" />
        <KpiCard label="Kampanye Aktif" :value="kpi?.active_campaigns" icon="campaign" :loading="loading" :hint="`dari ${kpi?.total_campaigns ?? 0} kampanye`" />
        <KpiCard label="Respons" :value="kpi?.responses" icon="forum" :loading="loading" hint="Pesan masuk tercatat" />
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <KpiCard label="Lead Kualifikasi" :value="kpi?.qualified_leads" icon="workspace_premium" tone="positive" :loading="loading" :hint="`dari ${kpi?.total_leads ?? 0} lead`" />
        <KpiCard label="Klien Baru" :value="kpi?.new_clients" icon="handshake" tone="positive" :loading="loading" />
        <KpiCard label="Proyek Aktif" :value="kpi?.active_projects" icon="folder_open" :loading="loading" />
        <KpiCard label="Pendapatan Terverifikasi" :value="kpi?.verified_revenue" format="currency" icon="account_balance_wallet" tone="positive" :loading="loading" hint="Pembayaran CONFIRMED" />
      </div>

      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-7">
        <KpiCard label="Komisi Tertunda" :value="kpi?.pending_commissions" format="currency" icon="pending_actions" tone="warning" :loading="loading" />
        <KpiCard label="Komisi Dibayar" :value="kpi?.paid_commissions" format="currency" icon="price_check" :loading="loading" />
        <KpiCard label="Konversi Referral" :value="kpi?.referral_conversions" icon="conversion_path" :loading="loading" :hint="`${kpi?.total_partners ?? 0} partner aktif`" />
        <KpiCard label="Task Terbuka" :value="kpi?.open_tasks" icon="task_alt" :loading="loading" :hint="`${kpi?.tasks_due ?? 0} jatuh tempo 7 hari`" />
      </div>

      <!-- Charts -->
      <div class="grid lg:grid-cols-2 gap-4 mb-7">
        <TrendChart :series="trends" metric="leads" label="Lead baru" :height="170" />
        <TrendChart :series="trends" metric="revenue" label="Pendapatan terverifikasi" format="currency" :height="170" />
      </div>

      <!-- Alerts -->
      <div v-if="alerts.length" class="mb-7">
        <h2 class="font-bold text-[15px] mb-3">Peringatan sistem</h2>
        <div class="grid md:grid-cols-3 gap-3">
          <RouterLink
            v-for="(a, i) in alerts" :key="i" :to="a.to"
            class="flex items-start gap-3 p-4 rounded-2xl border bg-surface-white shadow-card hover:shadow-card-hover transition-shadow"
            :class="a.tone === 'error' ? 'border-error/25' : 'border-tertiary/20'"
          >
            <span
              class="material-symbols-outlined shrink-0"
              :class="a.tone === 'error' ? 'text-on-error-container' : 'text-tertiary'"
            >{{ a.icon }}</span>
            <div class="min-w-0">
              <p class="font-semibold text-[14px]">{{ a.title }}</p>
              <p class="text-[12px] text-muted mt-0.5">{{ a.body }}</p>
            </div>
          </RouterLink>
        </div>
      </div>

      <!-- Activity + tasks -->
      <div class="grid lg:grid-cols-5 gap-4">
        <section class="lg:col-span-3 bg-surface-white border border-border-subtle rounded-2xl shadow-card overflow-hidden">
          <header class="px-5 py-4 border-b border-border-subtle flex items-center justify-between">
            <h2 class="font-bold text-[15px]">Aktivitas terbaru</h2>
            <span class="text-[12px] text-muted">dari data nyata</span>
          </header>
          <ul class="divide-y divide-border-subtle">
            <li v-if="loading" class="px-5 py-8 text-center text-muted text-[13px]">Memuat…</li>
            <li v-else-if="!activity.length" class="px-5 py-10 text-center text-muted text-[13px]">
              Belum ada aktivitas tercatat.
            </li>
            <li v-for="(a, i) in activity" :key="i" class="px-5 py-3 flex items-start gap-3">
              <span class="w-8 h-8 rounded-lg bg-surface-container-low grid place-items-center shrink-0">
                <span class="material-symbols-outlined text-[16px] text-secondary">{{ actIcon(a.kind) }}</span>
              </span>
              <div class="min-w-0 flex-1">
                <p class="text-[13.5px] font-medium truncate">{{ a.title }}</p>
                <p class="text-[12px] text-muted truncate">
                  {{ a.detail || LEAD_STAGE_LABEL[a.detail] || '—' }}
                </p>
              </div>
              <span class="text-[11px] text-muted shrink-0">{{ relTime(a.created_at) }}</span>
            </li>
          </ul>
        </section>

        <section class="lg:col-span-2 bg-surface-white border border-border-subtle rounded-2xl shadow-card overflow-hidden">
          <header class="px-5 py-4 border-b border-border-subtle">
            <h2 class="font-bold text-[15px]">Task mendatang</h2>
          </header>
          <ul class="divide-y divide-border-subtle">
            <li v-if="loading" class="px-5 py-8 text-center text-muted text-[13px]">Memuat…</li>
            <li v-else-if="!dueTasks.length" class="px-5 py-10 text-center text-muted text-[13px]">
              Tidak ada task terbuka.
            </li>
            <li v-for="t in dueTasks" :key="t.id" class="px-4 py-3 flex items-start gap-3">
              <button
                class="mt-0.5 w-5 h-5 rounded-md border-2 border-outline-variant hover:border-primary hover:bg-primary-fixed grid place-items-center transition-colors shrink-0"
                :title="'Tandai selesai'" @click="completeTask(t)"
              >
                <span class="material-symbols-outlined text-[14px] text-primary opacity-0 hover:opacity-100">check</span>
              </button>
              <div class="min-w-0 flex-1">
                <p class="text-[13.5px] font-medium leading-snug">{{ t.title }}</p>
                <p class="text-[11.5px] mt-0.5" :class="t.overdue ? 'text-on-error-container font-semibold' : 'text-muted'">
                  {{ t.dueLabel }}
                </p>
              </div>
              <StatusBadge :value="t.priority" />
            </li>
          </ul>
        </section>
      </div>
    </template>
  </SideNav>
</template>
