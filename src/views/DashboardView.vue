<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import SideNav from '../components/SideNav.vue'
import { listRequests, formatRupiah, DEADLINE_LABELS, STATUS_LABELS, waLink } from '../lib/api'

const router = useRouter()
const requests = ref([])
const loading = ref(true)

const stats = computed(() => {
  const all = requests.value
  return {
    new: all.filter((r) => r.status === 'new').length,
    review: all.filter((r) => r.status === 'review').length,
    working: all.filter((r) => r.status === 'working').length,
    deadlineToday: all.filter((r) => r.deadline === 'hari_ini').length,
  }
})

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
    <div class="mb-8">
      <h2 class="text-headline-md font-headline-md font-bold text-on-surface mb-2">Welcome back, Expert!</h2>
      <p class="text-body-md font-body-md text-secondary">Here's your queue for today. Let's get things Beres.</p>
    </div>

    <!-- Stats Overview Bento -->
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
      <div class="bg-surface-white p-4 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] hover:shadow-lg hover:border-electric-blue border border-transparent transition-all duration-200">
        <div class="flex items-center justify-between mb-2">
          <span class="text-secondary text-label-bold font-label-bold">New Requests</span>
          <span class="material-symbols-outlined text-electric-blue">inbox</span>
        </div>
        <div class="text-headline-lg font-headline-lg font-bold text-on-surface">{{ stats.new }}</div>
      </div>
      <div class="bg-surface-white p-4 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] hover:shadow-lg hover:border-electric-blue border border-transparent transition-all duration-200">
        <div class="flex items-center justify-between mb-2">
          <span class="text-secondary text-label-bold font-label-bold">Need Review</span>
          <span class="material-symbols-outlined text-tertiary-container">find_in_page</span>
        </div>
        <div class="text-headline-lg font-headline-lg font-bold text-on-surface">{{ stats.review }}</div>
      </div>
      <div class="bg-surface-white p-4 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] hover:shadow-lg hover:border-electric-blue border border-transparent transition-all duration-200">
        <div class="flex items-center justify-between mb-2">
          <span class="text-secondary text-label-bold font-label-bold">Working</span>
          <span class="material-symbols-outlined text-primary-container">engineering</span>
        </div>
        <div class="text-headline-lg font-headline-lg font-bold text-on-surface">{{ stats.working }}</div>
      </div>
      <div class="bg-error-container p-4 rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] hover:shadow-lg border-l-4 border-urgency-red transition-all duration-200">
        <div class="flex items-center justify-between mb-2">
          <span class="text-on-error-container text-label-bold font-label-bold flex items-center gap-1">
            <span class="material-symbols-outlined text-[16px]">warning</span>
            Deadline Today
          </span>
        </div>
        <div class="text-headline-lg font-headline-lg font-bold text-on-error-container">{{ stats.deadlineToday }}</div>
      </div>
    </div>

    <!-- Request List Table Area -->
    <div class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] overflow-hidden">
      <div class="p-6 border-b border-border-subtle flex justify-between items-center">
        <h3 class="text-body-lg font-body-lg font-bold text-on-surface">Active Queue</h3>
        <div class="flex gap-2">
          <button class="text-secondary hover:text-electric-blue transition-colors">
            <span class="material-symbols-outlined">filter_list</span>
          </button>
        </div>
      </div>

      <div v-if="loading" class="p-10 text-center">
        <span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span>
      </div>

      <div v-else-if="requests.length === 0" class="p-10 text-center">
        <span class="material-symbols-outlined text-5xl text-outline-variant mb-2">inbox</span>
        <p class="text-body-md font-body-md text-secondary">Belum ada request masuk.</p>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full text-left border-collapse">
          <thead>
            <tr class="bg-surface text-secondary text-label-sm font-label-sm uppercase tracking-wider">
              <th class="p-4 font-semibold">ID</th>
              <th class="p-4 font-semibold">Customer</th>
              <th class="p-4 font-semibold">Project</th>
              <th class="p-4 font-semibold">Problem</th>
              <th class="p-4 font-semibold">Deadline</th>
              <th class="p-4 font-semibold">Status</th>
              <th class="p-4 font-semibold">Quote</th>
              <th class="p-4 font-semibold text-right">Action</th>
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
              <td class="p-4 font-label-bold text-label-bold text-on-surface">{{ r.order_no }}</td>
              <td class="p-4 text-on-surface">{{ r.customer_name }}</td>
              <td class="p-4">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-label-sm font-label-sm bg-inverse-primary text-on-primary-fixed capitalize">{{ r.category }}</span>
              </td>
              <td class="p-4 text-on-surface-variant max-w-[200px] truncate">{{ r.description }}</td>
              <td class="p-4 font-label-bold text-label-bold flex items-center gap-1" :class="deadlineColor(r.deadline)">
                <span class="material-symbols-outlined text-[16px]">timer</span>
                {{ r.deadline_date ? new Date(r.deadline_date).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : (DEADLINE_LABELS[r.deadline] || r.deadline) }}
              </td>
              <td class="p-4">
                <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-label-sm font-label-sm" :class="statusClass(r.status)">
                  {{ STATUS_LABELS[r.status] || r.status }}
                </span>
              </td>
              <td class="p-4 text-secondary">{{ r.quote_amount ? formatRupiah(r.quote_amount) : '—' }}</td>
              <td class="p-4 text-right" @click.stop>
                <a
                  :href="waLink(r.whatsapp ? '62' + r.whatsapp : '6285166337257', `Halo ${r.customer_name}, ini engineer JokiTugasIT.id untuk request ${r.order_no}.`)"
                  target="_blank"
                  rel="noopener"
                  class="inline-flex items-center justify-center w-8 h-8 rounded-full bg-surface-container-high text-on-surface-variant hover:bg-success-green hover:text-on-primary transition-colors"
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