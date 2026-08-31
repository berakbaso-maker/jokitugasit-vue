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
                <span class="inline-flex items-center px-2.5 py-1 rounded-full text-label-sm font-label-sm bg-inverse-primary text-on-primary-fixed capitalize whitespace-nowrap">{{ r.category }}</span>
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
                  :href="waLink(r.whatsapp ? '62' + r.whatsapp : '6285166337257', `Halo ${r.customer_name}, ini engineer JokiTugasIT.id untuk request ${r.order_no}.`)"
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
