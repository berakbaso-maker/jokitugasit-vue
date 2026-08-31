<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { getPublicOrder, waLink, DEADLINE_LABELS, STATUS_LABELS, CATEGORY_LABELS } from '../lib/api'

const route = useRoute()
const router = useRouter()

const request = ref(null)
const loading = ref(true)
const errorMsg = ref('')

onMounted(async () => {
  try {
    const data = await getPublicOrder(route.params.orderNo)
    request.value = data
  } catch (err) {
    console.error(err)
    errorMsg.value = err.message || 'Gagal memuat status request.'
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="bg-background text-on-background antialiased min-h-screen flex flex-col items-center justify-center p-gutter">
    <main class="w-full max-w-lg">
      <div v-if="loading" class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-8 text-center">
        <span class="material-symbols-outlined animate-spin text-electric-blue text-4xl">progress_activity</span>
        <p class="font-body-md text-body-md text-secondary mt-4">Memuat status request...</p>
      </div>

      <div v-else-if="errorMsg" class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-8 text-center">
        <span class="material-symbols-outlined text-urgency-red text-5xl">error</span>
        <h1 class="font-headline-lg text-headline-lg text-on-surface mb-2 mt-4">Request tidak ditemukan</h1>
        <p class="font-body-md text-body-md text-secondary mb-6">{{ errorMsg }}</p>
        <button
          class="w-full h-[48px] bg-electric-blue hover:bg-primary text-white font-label-bold text-label-bold rounded-lg active:scale-[0.98] transition-transform shadow-md"
          @click="router.push('/request')"
        >
          Kirim Request Baru
        </button>
      </div>

      <div v-else-if="request" class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgba(15,23,42,0.08)] p-8 text-center transition-all duration-300 hover:shadow-lg hover:border-electric-blue border border-transparent">
        <div class="inline-flex items-center justify-center w-20 h-20 bg-success-green/10 rounded-full mb-6">
          <span class="material-symbols-outlined text-[40px] text-success-green" style="font-variation-settings: 'FILL' 1">check_circle</span>
        </div>
        <h1 class="font-headline-lg text-headline-lg text-on-surface mb-2">Project kamu sudah masuk 👌</h1>
        <p class="font-body-md text-body-md text-secondary mb-6">Tenang aja, engineer kami siap bantu beresin tugasmu. Ini nomor referensi kamu:</p>

        <div class="inline-block bg-surface-container-low px-4 py-2 rounded-lg mb-8">
          <span class="font-label-bold text-label-bold text-electric-blue uppercase tracking-widest">ID: {{ request.order_no }}</span>
        </div>

        <div class="bg-surface-bright border border-border-subtle rounded-lg p-4 mb-8 text-left">
          <h3 class="font-label-bold text-label-bold text-on-surface mb-4 border-b border-border-subtle pb-2">Ringkasan Request</h3>
          <div class="space-y-3">
            <div class="flex justify-between">
              <span class="font-body-md text-body-md text-secondary text-sm">Jenis Project</span>
              <span class="font-body-md text-body-md text-on-surface font-semibold text-sm capitalize">{{ CATEGORY_LABELS[request.category] || request.category }}</span>
            </div>
            <div class="flex justify-between">
              <span class="font-body-md text-body-md text-secondary text-sm">Tenggat Waktu</span>
              <span class="font-body-md text-body-md text-on-surface font-semibold text-sm">{{ request.deadline_date ? new Date(request.deadline_date).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : (DEADLINE_LABELS[request.deadline] || request.deadline) }}</span>
            </div>
            <div class="flex justify-between">
              <span class="font-body-md text-body-md text-secondary text-sm">Status</span>
              <div class="flex items-center gap-1.5">
                <span class="w-2 h-2 rounded-full bg-electric-blue animate-pulse"></span>
                <span class="font-body-md text-body-md text-electric-blue font-semibold text-sm">{{ STATUS_LABELS[request.status] || request.status }}</span>
              </div>
            </div>
          </div>
        </div>

        <div class="flex items-center justify-center gap-2 mb-6">
          <div class="w-2.5 h-2.5 rounded-full bg-success-green pulse-dot"></div>
          <span class="font-label-sm text-label-sm text-secondary">Engineer Available</span>
        </div>

        <button
          class="w-full h-[48px] border border-electric-blue text-electric-blue font-label-bold text-label-bold rounded-lg hover:bg-surface-container-low transition-colors mb-3"
          @click="router.push(`/track/${request.order_no}`)"
        >
          <span class="material-symbols-outlined align-middle text-[18px] mr-1">track_changes</span>
          Cek Status Order
        </button>
        <a
          :href="waLink(request.whatsapp ? '62' + request.whatsapp : '6285166337257', `Halo, saya ${request.customer_name} (${request.order_no}), mau lanjut diskusi project saya.`)"
          target="_blank"
          rel="noopener"
          class="w-full h-[48px] bg-[#25D366] hover:bg-[#20bd5a] text-white font-label-bold text-label-bold rounded-lg flex items-center justify-center gap-2 active:scale-[0.98] transition-transform shadow-md"
        >
          <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">chat</span>
          Lanjut Chat Engineer
        </a>
        <p class="font-label-sm text-label-sm text-secondary mt-4">Klik tombol di atas untuk diskusi detail &amp; harga via WhatsApp.</p>
      </div>

      <div class="mt-8 text-center">
        <a class="inline-flex items-center gap-2 text-electric-blue font-label-bold text-label-bold hover:underline cursor-pointer" @click="router.push('/')">
          <span class="material-symbols-outlined text-[18px]">arrow_back</span>
          Kembali ke Beranda
        </a>
      </div>
    </main>
  </div>
</template>