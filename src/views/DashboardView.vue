<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import SideNav from '../components/SideNav.vue'
import {
  listRequests, formatRupiah, DEADLINE_LABELS, STATUS_LABELS, CATEGORY_LABELS, waLink,
  getAnalyticsOverview, getAnalyticsFunnel,
} from '../lib/api'

const router = useRouter()
const requests = ref([])
const loading = ref(true)
const analytics = ref(null)
const funnel = ref([])
const analyticsError = ref('')

const stats = computed(() => {
  const all = requests.value
  return {
    new: all.filter((r) => r.status === 'new').length,
    review: all.filter((r) => r.status === 'review').length,
    working: all.filter((r) => r.status === 'working').length,
    deadlineToday: all.filter((r) => r.deadline === 'hari_ini').length,
  }
})

/** Rasio dihitung dari angka database; null kalau pembaginya nol. */
const rates = computed(() => {
  const a = analytics.value
  if (!a) return { response: null, interest: null, close: null }
  const sent = Number(a.contacts_sent || 0)
  const responses = Number(a.responses || 0)
  const interested = Number(a.interested || 0)
  const completed = Number(a.projects_completed || 0)
  return {
    response: sent > 0 ? (responses / sent) * 100 : null,
    interest: responses > 0 ? (interested / responses) * 100 : null,
    close: interested > 0 ? (completed / interested) * 100 : null,
  }
})

const pct = (value) => (value == null ? '—' : `${value.toFixed(1)}%`)

const deadlineColor = (d) => (d === 'hari_ini' ? 'text-urgency-red' : 'text-on-surface')

async function load() {
  loading.value = true
  try {
    requests.value = await listRequests()
  } catch (err) {
    console.error(err)
  } finally {
    loading.value = false
  }

  try {
    const [overview, funnelRows] = await Promise.all([
      getAnalyticsOverview(),
      getAnalyticsFunnel(),
    ])
    analytics.value = overview
    funnel.value = funnelRows || []
  } catch (err) {
    // Analytics butuh migration-money-schema.sql + outreach; jangan
    // sampai memblokir dashboard kalau belum dipasang.
    analyticsError.value = err.message || ''
    console.error(err)
  }
}

onMounted(load)

function goDetail(id) {
  router.push(`/requests/${id}`)
}

const statusClass = (s) => {
  switch (s) {
    case 'review':
      return 'bg-tertiary-container text-on-tertiary'
    case 'working':
      return 'bg-primary-container text-on-primary-container'
    case 'new':
      return 'bg-surface-container-highest text-on-surface-variant'
    default:
      return 'bg-surface-container-high text-on-surface-variant'
  }
}
</script>

<template>
  <SideNav>
    <!-- Header -->
    <div class="mb-8">
      <h1 class="text-headline-md font-headline-md font-bold text-on-surface">Dashboard Engineer</h1>
      <p class="text-body-md font-body-md text-secondary mt-1">Pantau request masuk dan prioritas hari ini.</p>
    </div>

    <!-- Stats Overview -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
      <div class="bg-surface-white p-5 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] border border-transparent hover:border-electric-blue hover:shadow-lg transition-all duration-200">
        <div class="flex items-center justify-between mb-3">
          <span class="text-secondary text-label-sm font-label-sm uppercase tracking-wide">Request Baru</span>
          <span class="w-9 h-9 rounded-lg bg-primary-fixed/40 text-electric-blue flex items-center justify-center">
            <span class="material-symbols-outlined text-[20px]">inbox</span>
          </span>
        </div>
        <div class="text-display-hero-mobile font-headline-md font-extrabold text-on-surface leading-none">{{ stats.new }}</div>
      </div>
      <div class="bg-surface-white p-5 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] border border-transparent hover:border-electric-blue hover:shadow-lg transition-all duration-200">
        <div class="flex items-center justify-between mb-3">
          <span class="text-secondary text-label-sm font-label-sm uppercase tracking-wide">Perlu Review</span>
          <span class="w-9 h-9 rounded-lg bg-tertiary-fixed/40 text-tertiary flex items-center justify-center">
            <span class="material-symbols-outlined text-[20px]">find_in_page</span>
          </span>
        </div>
        <div class="text-display-hero-mobile font-headline-md font-extrabold text-on-surface leading-none">{{ stats.review }}</div>
      </div>
      <div class="bg-surface-white p-5 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] border border-transparent hover:border-electric-blue hover:shadow-lg transition-all duration-200">
        <div class="flex items-center justify-between mb-3">
          <span class="text-secondary text-label-sm font-label-sm uppercase tracking-wide">Dikerjakan</span>
          <span class="w-9 h-9 rounded-lg bg-primary-container/30 text-primary flex items-center justify-center">
            <span class="material-symbols-outlined text-[20px]">engineering</span>
          </span>
        </div>
        <div class="text-display-hero-mobile font-headline-md font-extrabold text-on-surface leading-none">{{ stats.working }}</div>
      </div>
      <div class="bg-error-container p-5 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] border border-transparent hover:border-urgency-red hover:shadow-lg transition-all duration-200">
        <div class="flex items-center justify-between mb-3">
          <span class="text-on-error-container text-label-sm font-label-sm uppercase tracking-wide">Deadline Hari Ini</span>
          <span class="w-9 h-9 rounded-lg bg-white/30 text-on-error-container flex items-center justify-center">
            <span class="material-symbols-outlined text-[20px]">warning</span>
          </span>
        </div>
        <div class="text-display-hero-mobile font-headline-md font-extrabold text-on-error-container leading-none">{{ stats.deadlineToday }}</div>
      </div>
    </div>

    <!-- Funnel & Uang -->
    <div v-if="analytics" class="grid lg:grid-cols-2 gap-4 mb-8">
      <div class="bg-surface-white p-5 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)]">
        <h3 class="text-body-lg font-bold mb-1">Funnel Outreach</h3>
        <p class="text-label-sm text-secondary mb-4">Dari catatan kontak yang benar-benar tersimpan.</p>
        <div class="space-y-3">
          <div v-for="step in funnel" :key="step.stage">
            <div class="flex justify-between text-sm mb-1">
              <span class="font-medium text-on-surface">{{ step.stage }}</span>
              <span class="font-bold">{{ step.count }}</span>
            </div>
            <div class="h-2 rounded-full bg-surface-container overflow-hidden">
              <div
                class="h-full rounded-full bg-electric-blue"
                :style="{ width: `${funnel[0]?.count ? Math.min(100, (step.count / funnel[0].count) * 100) : 0}%` }"
              ></div>
            </div>
          </div>
        </div>
        <dl class="grid grid-cols-3 gap-3 mt-5 pt-4 border-t border-border-subtle text-center">
          <div>
            <dt class="text-[11px] text-secondary">Response</dt>
            <dd class="font-bold">{{ pct(rates.response) }}</dd>
          </div>
          <div>
            <dt class="text-[11px] text-secondary">Berminat</dt>
            <dd class="font-bold">{{ pct(rates.interest) }}</dd>
          </div>
          <div>
            <dt class="text-[11px] text-secondary">Closing</dt>
            <dd class="font-bold">{{ pct(rates.close) }}</dd>
          </div>
        </dl>
        <p class="text-[11px] text-secondary mt-3">
          Response = balasan / pesan terkirim. Closing = proyek selesai / berminat.
        </p>
      </div>

      <div class="bg-surface-white p-5 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)]">
        <h3 class="text-body-lg font-bold mb-1">Uang</h3>
        <p class="text-label-sm text-secondary mb-4">Pembayaran terkonfirmasi dan komisi dari tabel.</p>
        <dl class="space-y-3 text-sm">
          <div class="flex justify-between">
            <dt class="text-secondary">Omzet terkonfirmasi</dt>
            <dd class="font-bold">{{ formatRupiah(analytics.gross_confirmed) }}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-secondary">Komisi sudah dibayar</dt>
            <dd class="font-bold text-urgency-red">− {{ formatRupiah(analytics.commission_paid) }}</dd>
          </div>
          <div class="flex justify-between">
            <dt class="text-secondary">Komisi siap dibayar</dt>
            <dd class="font-bold text-amber-600">{{ formatRupiah(analytics.commission_unpaid) }}</dd>
          </div>
          <div class="flex justify-between border-t border-border-subtle pt-3">
            <dt class="font-bold">Sebelum biaya lain</dt>
            <dd class="font-bold text-electric-blue">
              {{ formatRupiah(Number(analytics.gross_confirmed || 0) - Number(analytics.commission_paid || 0)) }}
            </dd>
          </div>
        </dl>
        <p class="text-[11px] text-secondary mt-3">
          Ini belum dikurangi biaya operasional atau pajak, jadi bukan laba bersih.
        </p>
        <div class="grid grid-cols-2 gap-3 mt-4 pt-4 border-t border-border-subtle text-center">
          <div>
            <p class="text-[11px] text-secondary">Partner membawa deal</p>
            <p class="font-bold">{{ analytics.partners_with_deal }} / {{ analytics.active_partners }}</p>
          </div>
          <div>
            <p class="text-[11px] text-secondary">Prospek di antrean</p>
            <p class="font-bold">{{ analytics.prospects_queue }}</p>
          </div>
        </div>
      </div>
    </div>

    <div v-else-if="analyticsError" class="mb-8 rounded-xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
      Statistik belum tersedia. Jalankan <code class="font-mono">migration-outreach-schema.sql</code> dan
      <code class="font-mono">migration-money-schema.sql</code> di Supabase.
    </div>

    <!-- Active Queue -->
    <div class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] overflow-hidden">
      <div class="px-6 py-5 border-b border-border-subtle flex justify-between items-center">
        <div>
          <h3 class="text-body-lg font-body-lg font-bold text-on-surface">Antrian Request</h3>
          <p class="text-label-sm text-label-sm text-secondary mt-0.5">{{ requests.length }} request total</p>
        </div>
        <RouterLink
          to="/requests"
          class="inline-flex items-center gap-1.5 text-electric-blue font-label-bold text-label-bold hover:underline"
        >
          Lihat Semua
          <span class="material-symbols-outlined text-[18px]">arrow_forward</span>
        </RouterLink>
      </div>

      <div v-if="loading" class="p-12 text-center">
        <span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span>
        <p class="text-body-md font-body-md text-secondary mt-3">Memuat request...</p>
      </div>

      <div v-else-if="requests.length === 0" class="p-12 text-center">
        <div class="w-16 h-16 mx-auto rounded-2xl bg-surface-container-low flex items-center justify-center mb-4">
          <span class="material-symbols-outlined text-3xl text-outline-variant">inbox</span>
        </div>
        <h4 class="text-body-lg font-body-lg font-bold text-on-surface mb-1">Belum ada request masuk</h4>
        <p class="text-body-md font-body-md text-secondary mb-6">Request customer akan muncul di sini begitu masuk.</p>
        <button
          @click="router.push('/request')"
          class="inline-flex items-center gap-2 bg-electric-blue text-white font-label-bold text-label-bold px-5 py-3 rounded-lg hover:bg-primary transition-colors"
        >
          <span class="material-symbols-outlined text-[18px]">add_circle</span>
          Buat Request Contoh
        </button>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="bg-surface text-secondary text-label-sm font-label-sm uppercase tracking-wider">
              <th class="px-5 py-3.5 font-semibold">Order</th>
              <th class="px-5 py-3.5 font-semibold">Customer</th>
              <th class="px-5 py-3.5 font-semibold">Project</th>
              <th class="px-5 py-3.5 font-semibold">Deadline</th>
              <th class="px-5 py-3.5 font-semibold">Status</th>
              <th class="px-5 py-3.5 font-semibold">Quote</th>
              <th class="px-5 py-3.5 font-semibold text-right">Aksi</th>
            </tr>
          </thead>
          <tbody class="text-body-md font-body-md divide-y divide-border-subtle">
            <tr
              v-for="r in requests"
              :key="r.id"
              class="hover:bg-surface-container-lowest transition-colors cursor-pointer"
              :class="r.deadline === 'hari_ini' ? 'bg-error-container/10' : ''"
              @click="goDetail(r.id)"
            >
              <td class="px-5 py-4 font-label-bold text-label-bold text-on-surface whitespace-nowrap">#{{ r.order_no }}</td>
              <td class="px-5 py-4 text-on-surface whitespace-nowrap">{{ r.customer_name }}</td>
              <td class="px-5 py-4">
                <span class="inline-flex items-center px-2.5 py-1 rounded-full text-label-sm font-label-sm bg-inverse-primary text-on-primary-fixed capitalize whitespace-nowrap">{{ CATEGORY_LABELS[r.category] || r.category }}</span>
              </td>
              <td class="px-5 py-4 font-label-bold text-label-bold whitespace-nowrap" :class="deadlineColor(r.deadline)">
                <span class="material-symbols-outlined text-[16px] align-middle mr-1">timer</span>
                {{ r.deadline_date ? new Date(r.deadline_date).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : (DEADLINE_LABELS[r.deadline] || r.deadline) }}
              </td>
              <td class="px-5 py-4">
                <span class="inline-flex items-center px-2.5 py-1 rounded-full text-label-sm font-label-sm whitespace-nowrap" :class="statusClass(r.status)">
                  {{ STATUS_LABELS[r.status] || r.status }}
                </span>
              </td>
              <td class="px-5 py-4 text-secondary whitespace-nowrap">{{ r.quote_amount ? formatRupiah(r.quote_amount) : '—' }}</td>
              <td class="px-5 py-4 text-right whitespace-nowrap" @click.stop>
                <a
                  :href="waLink(r.whatsapp ? '62' + r.whatsapp : '6285166337257', `Halo ${r.customer_name}, ini engineer jokitugasit.my.id untuk request ${r.order_no}.`)"
                  target="_blank"
                  rel="noopener"
                  class="inline-flex items-center justify-center w-9 h-9 rounded-full bg-surface-container-high text-on-surface-variant hover:bg-success-green hover:text-white transition-colors"
                  title="WhatsApp Customer"
                >
                  <span class="material-symbols-outlined text-[18px]">chat</span>
                </a>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </SideNav>
</template>
