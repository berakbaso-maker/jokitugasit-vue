<script setup>
import { ref, computed, onMounted } from 'vue'
import SideNav from '../components/SideNav.vue'
import {
  listPayments, listCommissions, getAnalyticsOverview, formatRupiah,
} from '../lib/api'
import {
  PAYMENT_KIND_LABELS, PAYMENT_STATUS_LABELS, summarizePayments,
} from '../lib/money'
import { pesanGalat } from '../lib/galat'

const payments = ref([])
const commissions = ref([])
const analytics = ref(null)
const loading = ref(true)
const error = ref('')

const summary = computed(() => summarizePayments(payments.value))

/**
 * Angka kepala memakai RPC analytics supaya sama persis dengan
 * Dashboard. Tidak ada penjumlahan omzet yang dilakukan di browser.
 */
const stats = computed(() => {
  const gross = Number(analytics.value?.gross_confirmed || 0)
  const commissionPaid = Number(analytics.value?.commission_paid || 0)
  return {
    gross,
    commissionPaid,
    commissionUnpaid: Number(analytics.value?.commission_unpaid || 0),
    beforeExpense: gross - commissionPaid,
    refunded: summary.value.refunded,
    paymentRows: payments.value.filter(p => p.status === 'CONFIRMED').length,
  }
})

const visiblePayments = computed(() => payments.value.slice(0, 50))

const COMMISSION_LABELS = {
  PENDING: 'Menunggu pelunasan',
  ELIGIBLE: 'Siap dibayar',
  PAID: 'Sudah dibayar',
  VOID: 'Batal',
  ADJUSTMENT: 'Perlu review',
}

const commissionClass = (s) => {
  if (s === 'PAID') return 'bg-success-green/10 text-success-green border border-success-green/20'
  if (s === 'ELIGIBLE') return 'bg-urgency-red/10 text-urgency-red border border-urgency-red/20'
  if (s === 'ADJUSTMENT') return 'bg-amber-100 text-amber-700 border border-amber-200'
  return 'bg-surface-container-high text-secondary border border-outline-variant'
}

const paymentClass = (s) => {
  if (s === 'CONFIRMED') return 'bg-success-green/10 text-success-green'
  if (s === 'VOID') return 'bg-error-container text-on-error-container'
  return 'bg-surface-container text-on-surface-variant'
}

function fmtDate(iso) {
  if (!iso) return '-'
  return new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

onMounted(async () => {
  loading.value = true
  error.value = ''
  try {
    const [pays, comms, overview] = await Promise.all([
      listPayments(),
      listCommissions({ limit: 20 }),
      getAnalyticsOverview(),
    ])
    payments.value = pays || []
    commissions.value = comms || []
    analytics.value = overview || null
  } catch (err) {
    error.value = err.message?.includes('relation') || err.code === '42P01'
      ? 'Tabel pembayaran/komisi belum terpasang. Jalankan migration-money-schema.sql lalu migration-payment-flow.sql.'
      : pesanGalat(err, 'Gagal memuat data pendapatan.')
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <SideNav>
    <div class="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4">
      <div>
        <h2 class="text-display-hero-mobile md:text-display-hero font-display-hero-mobile md:font-display-hero text-on-surface">Ringkasan Pendapatan</h2>
        <p class="font-body-lg text-body-lg text-secondary mt-1">
          Dihitung dari pembayaran yang benar-benar tercatat, bukan dari status manual.
        </p>
      </div>
      <RouterLink
        to="/requests"
        class="bg-accent-fill text-on-primary font-label-bold text-label-bold px-6 py-3 rounded-lg hover:scale-[0.98] transition-transform shadow-soft flex items-center gap-2 w-full md:w-auto justify-center"
      >
        <span class="material-symbols-outlined">add_card</span>
        Catat Pembayaran
      </RouterLink>
    </div>

    <div v-if="error" class="mb-6 rounded-xl border border-urgency-red/30 bg-error-container p-4 text-sm text-on-error-container">
      {{ error }}
    </div>

    <div v-if="loading" class="p-10 text-center">
      <span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span>
    </div>

    <template v-else>
      <!-- Stats Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <div class="bg-surface-white p-6 rounded-xl shadow-soft hover:shadow-[0_8px_30px_rgb(var(--shadow-color) / 0.12)] hover:border hover:border-electric-blue transition-all group">
          <div class="flex items-center justify-between mb-4">
            <span class="font-label-bold text-label-bold text-secondary">Omzet Terkonfirmasi</span>
            <span class="material-symbols-outlined text-electric-blue bg-primary-fixed/30 p-2 rounded-lg group-hover:bg-primary-fixed/50 transition-colors">account_balance</span>
          </div>
          <div class="text-headline-lg font-headline-lg text-on-surface mb-1">{{ formatRupiah(stats.gross) }}</div>
          <div class="font-label-sm text-label-sm text-secondary flex items-center gap-1">
            <span class="material-symbols-outlined text-[14px]">receipt_long</span> {{ stats.paymentRows }} pembayaran · sebelum refund
          </div>
        </div>

        <div class="bg-surface-white p-6 rounded-xl shadow-soft hover:shadow-[0_8px_30px_rgb(var(--shadow-color) / 0.12)] hover:border hover:border-electric-blue transition-all group">
          <div class="flex items-center justify-between mb-4">
            <span class="font-label-bold text-label-bold text-secondary">Komisi Siap Dibayar</span>
            <span class="material-symbols-outlined text-urgency-red bg-error-container/50 p-2 rounded-lg">pending_actions</span>
          </div>
          <div class="text-headline-lg font-headline-lg text-on-surface mb-1">{{ formatRupiah(stats.commissionUnpaid) }}</div>
          <div class="font-label-sm text-label-sm text-secondary">Baru muncul setelah proyek lunas</div>
        </div>

        <div class="bg-surface-white p-6 rounded-xl shadow-soft hover:shadow-[0_8px_30px_rgb(var(--shadow-color) / 0.12)] hover:border hover:border-electric-blue transition-all group">
          <div class="flex items-center justify-between mb-4">
            <span class="font-label-bold text-label-bold text-secondary">Komisi Sudah Dibayar</span>
            <span class="material-symbols-outlined text-success-green bg-success-green/10 p-2 rounded-lg">paid</span>
          </div>
          <div class="text-headline-lg font-headline-lg text-on-surface mb-1">{{ formatRupiah(stats.commissionPaid) }}</div>
          <div class="font-label-sm text-label-sm text-secondary">Dicatat di tabel komisi</div>
        </div>

        <div class="bg-surface-white p-6 rounded-xl shadow-soft hover:shadow-[0_8px_30px_rgb(var(--shadow-color) / 0.12)] hover:border hover:border-electric-blue transition-all group">
          <div class="flex items-center justify-between mb-4">
            <span class="font-label-bold text-label-bold text-secondary">Sebelum Biaya Lain</span>
            <span class="material-symbols-outlined text-electric-blue bg-primary-fixed/30 p-2 rounded-lg">trending_up</span>
          </div>
          <div class="text-headline-lg font-headline-lg text-on-surface mb-1">{{ formatRupiah(stats.beforeExpense) }}</div>
          <div class="font-label-sm text-label-sm text-secondary">Omzet − komisi. Belum biaya/pajak.</div>
        </div>
      </div>

      <!-- Arus pembayaran -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
        <div class="bg-surface-white p-5 rounded-xl border border-border-subtle">
          <p class="text-label-sm text-secondary mb-1">Diterima (DP + pelunasan)</p>
          <p class="text-headline-md font-bold">{{ formatRupiah(summary.paid) }}</p>
        </div>
        <div class="bg-surface-white p-5 rounded-xl border border-border-subtle">
          <p class="text-label-sm text-secondary mb-1">Refund tercatat</p>
          <p class="text-headline-md font-bold text-urgency-red">− {{ formatRupiah(summary.refunded) }}</p>
        </div>
        <div class="bg-surface-white p-5 rounded-xl border border-border-subtle">
          <p class="text-label-sm text-secondary mb-1">Nilai bersih diterima</p>
          <p class="text-headline-md font-bold text-success-green">{{ formatRupiah(summary.net) }}</p>
        </div>
      </div>

      <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
        <!-- Payments -->
        <div class="xl:col-span-2 bg-surface-white rounded-xl shadow-soft border border-border-subtle/50 overflow-hidden">
          <div class="p-6 border-b border-border-subtle flex justify-between items-center">
            <h3 class="text-headline-md font-headline-md text-on-surface">Pembayaran Terbaru</h3>
            <RouterLink to="/requests" class="text-electric-blue font-label-bold text-label-bold hover:underline">Lihat Semua</RouterLink>
          </div>

          <div v-if="payments.length === 0" class="p-10 text-center">
            <span class="material-symbols-outlined text-5xl text-outline-variant mb-2">account_balance</span>
            <p class="text-body-md text-secondary">Belum ada pembayaran tercatat.</p>
            <p class="text-label-sm text-outline mt-1">Buka detail request lalu catat DP atau pelunasan.</p>
          </div>

          <div v-else class="overflow-x-auto">
            <table class="w-full text-left border-collapse">
              <thead>
                <tr class="bg-surface border-b border-border-subtle">
                  <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Order</th>
                  <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Jenis</th>
                  <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Nominal</th>
                  <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Tanggal</th>
                  <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Status</th>
                </tr>
              </thead>
              <tbody class="font-body-md text-body-md text-on-surface divide-y divide-border-subtle">
                <tr v-for="p in visiblePayments" :key="p.id" class="hover:bg-surface-container-low transition-colors">
                  <td class="p-4 text-sm">
                    <RouterLink v-if="p.request_id" :to="`/requests/${p.request_id}`" class="font-bold text-electric-blue hover:underline">
                      {{ p.requests?.order_no || '—' }}
                    </RouterLink>
                    <span v-else class="font-bold">—</span>
                    <span class="block text-[11px] text-secondary truncate">{{ p.requests?.customer_name }}</span>
                  </td>
                  <td class="p-4 text-sm">{{ PAYMENT_KIND_LABELS[p.kind] || p.kind }}</td>
                  <td class="p-4 font-label-bold text-label-bold">{{ formatRupiah(p.amount) }}</td>
                  <td class="p-4 text-secondary text-sm">{{ fmtDate(p.paid_at || p.created_at) }}</td>
                  <td class="p-4">
                    <span class="font-label-sm text-label-sm px-2 py-1 rounded-full" :class="paymentClass(p.status)">
                      {{ PAYMENT_STATUS_LABELS[p.status] || p.status }}
                    </span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <!-- Commissions -->
        <div class="bg-surface-white rounded-xl shadow-soft border border-border-subtle/50 overflow-hidden">
          <div class="p-6 border-b border-border-subtle flex justify-between items-center">
            <h3 class="text-headline-md font-headline-md text-on-surface">Komisi Referral</h3>
            <RouterLink to="/engineer/partners" class="text-electric-blue font-label-bold text-label-bold hover:underline">Kelola</RouterLink>
          </div>

          <div v-if="commissions.length === 0" class="p-8 text-center">
            <span class="material-symbols-outlined text-5xl text-outline-variant mb-2">handshake</span>
            <p class="text-body-md text-secondary">Belum ada komisi.</p>
            <p class="text-label-sm text-outline mt-1">Komisi muncul setelah proyek dengan kode referral lunas.</p>
          </div>

          <ul v-else class="divide-y divide-border-subtle">
            <li v-for="c in commissions" :key="c.id" class="p-4">
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <p class="font-bold text-sm truncate">{{ c.partners?.full_name || 'Partner' }}</p>
                  <p class="text-[11px] text-secondary font-mono">{{ c.partners?.referral_code }}</p>
                  <p class="text-[11px] text-secondary mt-1">
                    {{ c.requests?.order_no || '—' }} · {{ fmtDate(c.created_at) }}
                  </p>
                </div>
                <div class="text-right shrink-0">
                  <p class="font-bold text-sm">{{ formatRupiah(c.amount) }}</p>
                  <span class="inline-block mt-1 text-[10px] px-2 py-0.5 rounded-full" :class="commissionClass(c.status)">
                    {{ COMMISSION_LABELS[c.status] || c.status }}
                  </span>
                </div>
              </div>
            </li>
          </ul>
        </div>
      </div>
    </template>
  </SideNav>
</template>
