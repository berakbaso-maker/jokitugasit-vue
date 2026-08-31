<script setup>
import { ref, computed, onMounted } from 'vue'
import SideNav from '../components/SideNav.vue'
import { listTransactions, formatRupiah } from '../lib/api'

const transactions = ref([])
const loading = ref(true)

const stats = computed(() => {
  const all = transactions.value
  const paid = all.filter((t) => t.status === 'paid')
  const pending = all.filter((t) => t.status === 'pending')
  const totalEarnings = paid.reduce((s, t) => s + (Number(t.amount) || 0), 0)
  const pendingAmount = pending.reduce((s, t) => s + (Number(t.amount) || 0), 0)
  return {
    totalEarnings,
    pending: pendingAmount,
    pendingCount: pending.length,
    monthIncome: paid
      .filter((t) => {
        const d = t.created_at ? new Date(t.created_at) : new Date()
        const now = new Date()
        return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()
      })
      .reduce((s, t) => s + (Number(t.amount) || 0), 0),
    successRate: all.length ? Math.round((paid.length / all.length) * 100) : 0,
    completed: paid.length,
  }
})

const statusClass = (s) =>
  s === 'paid' ? 'bg-success-green/10 text-success-green border border-success-green/20' : 'bg-surface-container-high text-secondary border border-outline-variant'

function fmtDate(iso) {
  if (!iso) return '-'
  return new Date(iso).toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' })
}

onMounted(async () => {
  loading.value = true
  try {
    transactions.value = await listTransactions()
  } catch (err) {
    console.error(err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <SideNav>
    <div class="flex flex-col md:flex-row justify-between items-start md:items-center mb-8 gap-4">
      <div>
        <h2 class="text-display-hero-mobile md:text-display-hero font-display-hero-mobile md:font-display-hero text-on-surface">Earnings Overview</h2>
        <p class="font-body-lg text-body-lg text-secondary mt-1">Track your income and request withdrawals.</p>
      </div>
      <button class="bg-electric-blue text-surface-white font-label-bold text-label-bold px-6 py-3 rounded-lg hover:scale-[0.98] transition-transform shadow-soft flex items-center gap-2 w-full md:w-auto justify-center">
        <span class="material-symbols-outlined">account_balance_wallet</span>
        Withdraw Funds
      </button>
    </div>

    <!-- Stats Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
      <div class="bg-surface-white p-6 rounded-xl shadow-soft hover:shadow-[0_8px_30px_rgba(15,23,42,0.12)] hover:border hover:border-electric-blue transition-all group">
        <div class="flex items-center justify-between mb-4">
          <span class="font-label-bold text-label-bold text-secondary">Total Earnings</span>
          <span class="material-symbols-outlined text-electric-blue bg-primary-fixed/30 p-2 rounded-lg group-hover:bg-primary-fixed/50 transition-colors">account_balance</span>
        </div>
        <div class="text-headline-lg font-headline-lg text-on-surface mb-1">{{ formatRupiah(stats.totalEarnings) }}</div>
        <div class="font-label-sm text-label-sm text-success-green flex items-center gap-1">
          <span class="material-symbols-outlined text-[14px]">trending_up</span> {{ stats.completed }} Completed Projects
        </div>
      </div>

      <div class="bg-surface-white p-6 rounded-xl shadow-soft hover:shadow-[0_8px_30px_rgba(15,23,42,0.12)] hover:border hover:border-electric-blue transition-all group">
        <div class="flex items-center justify-between mb-4">
          <span class="font-label-bold text-label-bold text-secondary">Pending Payments</span>
          <span class="material-symbols-outlined text-electric-blue bg-primary-fixed/30 p-2 rounded-lg group-hover:bg-primary-fixed/50 transition-colors">schedule</span>
        </div>
        <div class="text-headline-lg font-headline-lg text-on-surface mb-1">{{ formatRupiah(stats.pending) }}</div>
        <div class="font-label-sm text-label-sm text-secondary">From {{ stats.pendingCount }} active projects</div>
      </div>

      <div class="bg-surface-white p-6 rounded-xl shadow-soft hover:shadow-[0_8px_30px_rgba(15,23,42,0.12)] hover:border hover:border-electric-blue transition-all group">
        <div class="flex items-center justify-between mb-4">
          <span class="font-label-bold font-label-bold text-secondary">This Month Income</span>
          <span class="material-symbols-outlined text-electric-blue bg-primary-fixed/30 p-2 rounded-lg group-hover:bg-primary-fixed/50 transition-colors">calendar_month</span>
        </div>
        <div class="text-headline-lg font-headline-lg text-on-surface mb-1">{{ formatRupiah(stats.monthIncome) }}</div>
        <div class="font-label-sm text-label-sm text-secondary">Bulan berjalan</div>
      </div>

      <div class="bg-surface-white p-6 rounded-xl shadow-soft hover:shadow-[0_8px_30px_rgba(15,23,42,0.12)] hover:border hover:border-electric-blue transition-all group">
        <div class="flex items-center justify-between mb-4">
          <span class="font-label-bold font-label-bold text-secondary">Success Rate</span>
          <span class="material-symbols-outlined text-electric-blue bg-primary-fixed/30 p-2 rounded-lg group-hover:bg-primary-fixed/50 transition-colors">verified</span>
        </div>
        <div class="text-headline-lg font-headline-lg text-on-surface mb-1">{{ stats.successRate }}%</div>
        <div class="font-label-sm text-label-sm text-success-green">{{ stats.completed }} Completed Projects</div>
      </div>
    </div>

    <!-- Chart Area -->
    <div class="bg-surface-white p-6 rounded-xl shadow-soft mb-8 border border-border-subtle/50">
      <div class="flex justify-between items-center mb-6">
        <h3 class="text-headline-md font-headline-md text-on-surface">Income Trends</h3>
        <select class="bg-surface border-border-subtle rounded-lg font-label-sm text-label-sm px-3 py-2 text-secondary focus:ring-electric-blue focus:border-electric-blue">
          <option>Monthly</option>
          <option>Weekly</option>
        </select>
      </div>
      <div class="w-full h-64 bg-surface-container-low rounded-lg flex items-center justify-center border border-dashed border-outline-variant">
        <span class="text-secondary font-body-md text-body-md flex items-center gap-2">
          <span class="material-symbols-outlined">bar_chart</span>
          Chart visualization area
        </span>
      </div>
    </div>

    <!-- Recent Transactions Table -->
    <div class="bg-surface-white rounded-xl shadow-soft border border-border-subtle/50 overflow-hidden">
      <div class="p-6 border-b border-border-subtle flex justify-between items-center">
        <h3 class="text-headline-md font-headline-md text-on-surface">Recent Transactions</h3>
        <button class="text-electric-blue font-label-bold text-label-bold hover:underline">View All</button>
      </div>

      <div v-if="loading" class="p-10 text-center">
        <span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span>
      </div>

      <div v-else-if="transactions.length === 0" class="p-10 text-center">
        <span class="material-symbols-outlined text-5xl text-outline-variant mb-2">account_balance</span>
        <p class="text-body-md text-secondary">Belum ada transaksi.</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="bg-surface border-b border-border-subtle">
              <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">ID</th>
              <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Customer</th>
              <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Project</th>
              <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Amount</th>
              <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Date</th>
              <th class="p-4 font-label-sm text-label-sm text-secondary uppercase tracking-wider">Status</th>
            </tr>
          </thead>
          <tbody class="font-body-md text-body-md text-on-surface divide-y divide-border-subtle">
            <tr v-for="t in transactions" :key="t.id" class="hover:bg-surface-container-low transition-colors">
              <td class="p-4 font-label-bold text-label-bold text-secondary">{{ t.transaction_no }}</td>
              <td class="p-4">{{ t.customer_name }}</td>
              <td class="p-4">{{ t.project_label }}</td>
              <td class="p-4 font-label-bold text-label-bold">{{ formatRupiah(t.amount) }}</td>
              <td class="p-4 text-secondary">{{ fmtDate(t.created_at) }}</td>
              <td class="p-4">
                <span class="font-label-sm text-label-sm px-2 py-1 rounded-full capitalize" :class="statusClass(t.status)">{{ t.status }}</span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </SideNav>
</template>