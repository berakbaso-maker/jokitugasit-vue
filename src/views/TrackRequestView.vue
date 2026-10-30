<script setup>
import { computed, ref } from 'vue'
import { useRoute, useRouter, RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { getPublicOrder, DEADLINE_LABELS, STATUS_LABELS, CATEGORY_LABELS, formatRupiah, waLink } from '../lib/api'
import { bisaDiulang, detailGalat, pesanGalat } from '../lib/galat'
import KotakGalat from '../components/KotakGalat.vue'

const route = useRoute()
const router = useRouter()
const orderNo = ref(String(route.params.orderNo || route.query.order || '').toUpperCase())
const request = ref(null)
const loading = ref(false)
const errorMsg = ref('')
const errorDetail = ref('')
const errorBisaUlang = ref(false)
const steps = [
  { key: 'new', label: 'Request diterima', icon: 'inbox', copy: 'Detail project sudah masuk ke sistem.' },
  { key: 'consultation', label: 'Konsultasi', icon: 'forum', copy: 'Engineer sedang memeriksa kebutuhan project.' },
  { key: 'working', label: 'Sedang dikerjakan', icon: 'engineering', copy: 'Project sedang dikerjakan oleh engineer.' },
  { key: 'review', label: 'Siap direview', icon: 'rate_review', copy: 'Hasil project siap kamu periksa.' },
  { key: 'done', label: 'Selesai', icon: 'task_alt', copy: 'Project sudah selesai dan siap digunakan.' },
]
const stepIndex = computed(() => {
  if (request.value?.status === 'paid') return steps.length - 1
  const i = steps.findIndex((step) => step.key === request.value?.status)
  return i < 0 ? 0 : i
})
const isComplete = (i) => i <= stepIndex.value
async function track() {
  errorMsg.value = ''; errorDetail.value = ''; errorBisaUlang.value = false; request.value = null
  const value = orderNo.value.trim().toUpperCase()
  if (!value) { errorMsg.value = 'Masukkan nomor order terlebih dahulu.'; return }
  loading.value = true
  try {
    const data = await getPublicOrder(value)
    if (!data) throw new Error('Nomor order tidak ditemukan. Periksa kembali penulisannya.')
    request.value = data; orderNo.value = value
  } catch (error) {
    // Jangan pernah tampilkan error.message mentah ("TypeError: Failed to fetch").
    errorMsg.value = pesanGalat(error, 'Gagal mencari request. Coba lagi.')
    errorDetail.value = detailGalat(error)
    errorBisaUlang.value = bisaDiulang(error)
  }
  finally { loading.value = false }
}
if (route.params.orderNo || route.query.order) track()
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main id="konten-utama" tabindex="-1" class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <section class="max-w-2xl mx-auto text-center mb-10 md:mb-14">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5"><span class="material-symbols-outlined text-electric-blue text-[18px]">track_changes</span><span class="font-label-sm text-label-sm text-secondary">Request Tracker</span></div>
        <h1 class="font-headline-lg text-headline-lg md:text-display-hero-mobile text-on-surface mb-3">Cek status project kamu</h1>
        <p class="text-body-lg font-body-lg text-on-surface-variant">Masukkan nomor order untuk melihat progress request secara real-time.</p>
      </section>
      <section class="max-w-2xl mx-auto bg-surface-white rounded-xl shadow-[0px_4px_20px_rgb(var(--shadow-color) / 0.08)] p-5 md:p-7 mb-8">
        <form class="flex flex-col sm:flex-row gap-3" @submit.prevent="track"><label class="sr-only" for="order-number">Nomor order</label><input id="order-number" v-model="orderNo" type="text" placeholder="Contoh: JT1024" autocomplete="off" class="flex-1 min-w-0 h-12 rounded-lg border border-outline-variant bg-surface px-4 font-body-md text-on-surface uppercase outline-none focus:border-electric-blue focus:ring-2 focus:ring-electric-blue/20" /><button type="submit" :disabled="loading" class="h-12 px-6 rounded-lg bg-accent-fill text-white font-label-bold text-label-bold shadow-md hover:bg-accent-fill disabled:opacity-60 transition-colors"><span v-if="loading" class="material-symbols-outlined animate-spin align-middle">progress_activity</span><span v-else>Cek Status</span></button></form>
        <KotakGalat
          v-if="errorMsg"
          class="mt-4"
          :pesan="errorMsg"
          :detail="errorDetail"
          :bisa-ulang="errorBisaUlang"
          @coba-lagi="track"
        />
      </section>
      <section v-if="request" class="max-w-3xl mx-auto space-y-6">
        <div class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgb(var(--shadow-color) / 0.08)] p-6 md:p-8"><div class="flex flex-col sm:flex-row sm:items-start sm:justify-between gap-4 border-b border-border-subtle pb-6 mb-7"><div><p class="font-label-sm text-label-sm text-secondary uppercase tracking-wider mb-2">Nomor order</p><h2 class="font-headline-md text-headline-md font-bold">#{{ request.order_no }}</h2><p class="text-sm text-secondary mt-1">{{ request.customer_name }} · {{ CATEGORY_LABELS[request.category] || request.category }}</p></div><span class="self-start inline-flex rounded-full px-3 py-1.5 bg-primary-container text-white font-label-sm text-label-sm">{{ STATUS_LABELS[request.status] || request.status }}</span></div>
          <div class="space-y-0"><div v-for="(step, index) in steps" :key="step.key" class="relative flex gap-4 min-h-[76px]"><div v-if="index < steps.length - 1" class="absolute left-[17px] top-9 w-0.5 h-[76px]" :class="isComplete(index + 1) ? 'bg-accent-fill' : 'bg-border-subtle'"></div><div class="relative z-10 flex items-center justify-center w-9 h-9 shrink-0 rounded-full" :class="isComplete(index) ? 'bg-accent-fill text-white' : 'bg-surface-container text-secondary'"><span class="material-symbols-outlined text-[19px]">{{ step.icon }}</span></div><div class="pt-1 pb-5"><p class="font-label-bold text-label-bold" :class="isComplete(index) ? 'text-on-surface' : 'text-secondary'">{{ step.label }}</p><p class="text-sm text-secondary mt-1">{{ step.copy }}</p></div></div></div>
        </div>
        <div class="grid md:grid-cols-2 gap-6"><div class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgb(var(--shadow-color) / 0.08)] p-6"><h3 class="font-body-lg text-body-lg font-bold mb-4">Ringkasan request</h3><dl class="space-y-3 text-sm"><div class="flex justify-between gap-4"><dt class="text-secondary">Kategori</dt><dd class="font-semibold capitalize">{{ request.category }}</dd></div><div class="flex justify-between gap-4"><dt class="text-secondary">Deadline</dt><dd class="font-semibold">{{ request.deadline_date ? new Date(request.deadline_date).toLocaleDateString('id-ID', { day: '2-digit', month: 'short', year: 'numeric' }) : (DEADLINE_LABELS[request.deadline] || request.deadline) }}</dd></div><div v-if="request.quote_amount" class="flex justify-between gap-4"><dt class="text-secondary">Quote</dt><dd class="font-semibold">{{ formatRupiah(request.quote_amount) }}</dd></div></dl><div class="mt-5 pt-5 border-t border-border-subtle"><p class="text-label-sm font-label-sm text-secondary uppercase tracking-wider mb-2">Deskripsi</p><p class="text-sm leading-6 text-on-surface-variant">{{ request.description }}</p></div></div><div class="bg-primary-container rounded-xl p-6 text-white flex flex-col justify-between"><div><span class="material-symbols-outlined text-3xl mb-3">support_agent</span><h3 class="font-headline-md text-headline-md font-bold mb-2">Butuh bantuan?</h3><p class="text-sm text-white/80 leading-6">Hubungi engineer jika ada detail project yang ingin ditanyakan.</p></div><a :href="waLink(request.whatsapp ? '62' + request.whatsapp : '6285166337257', `Halo, saya ingin menanyakan status order #${request.order_no}`)" target="_blank" rel="noopener" class="inline-flex items-center justify-center gap-2 h-11 mt-6 rounded-lg bg-white text-primary font-label-bold text-label-bold hover:bg-primary-fixed"><span class="material-symbols-outlined text-[19px]">chat</span> Chat WhatsApp</a></div></div>

        <!-- Delivery Walkthrough Box (If review, done, or paid) -->
        <div v-if="['review', 'done', 'paid'].includes(request.status)" class="bg-surface-white rounded-2xl border border-electric-blue/40 shadow-sm p-6 sm:p-7">
          <div class="flex items-center gap-2 mb-3">
            <span class="material-symbols-outlined text-electric-blue text-2xl">school</span>
            <h3 class="font-bold text-lg text-on-surface">Delivery & Cheatsheet Demo Dosen</h3>
          </div>
          <p class="text-sm text-secondary mb-5">
            Setiap pengerjaan di jokitugasit.my.id dilengkapi panduan teknis agar kamu paham alur kode dan siap menjawab saat ditanya dosen/asisten lab.
          </p>

          <div class="space-y-4">
            <div v-if="request.walkthrough_url" class="p-4 rounded-xl bg-primary-fixed/20 border border-electric-blue/30 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <span class="text-xs font-bold uppercase tracking-wider text-electric-blue">Video Walkthrough Kode</span>
                <p class="text-sm font-semibold text-on-surface mt-0.5">Penjelasan alur fungsi & struktur file oleh engineer.</p>
              </div>
              <a :href="request.walkthrough_url" target="_blank" rel="noopener" class="bg-accent-fill text-white px-4 py-2.5 rounded-xl font-bold text-xs inline-flex items-center gap-1.5 shrink-0 shadow-xs hover:bg-accent-fill transition-colors">
                <span class="material-symbols-outlined text-[16px]">play_circle</span>
                Tonton Video
              </a>
            </div>

            <div v-if="request.walkthrough_notes" class="p-4 rounded-xl bg-surface-container-low border border-border-subtle">
              <span class="text-xs font-bold uppercase tracking-wider text-secondary">Cheatsheet Tanya-Jawab Dosen</span>
              <p class="text-xs font-mono whitespace-pre-wrap text-on-surface mt-2 leading-relaxed bg-surface-white p-3 rounded-lg border border-border-subtle/80">{{ request.walkthrough_notes }}</p>
            </div>

            <div class="p-3.5 rounded-xl bg-success-green/5 border border-success-green/30 flex items-center gap-2 text-xs text-success-green font-medium">
              <span class="material-symbols-outlined text-[18px]">verified</span>
              <span>Garansi Perbaikan & Tanya Jawab Gratis jika ada runtime error saat demo.</span>
            </div>
          </div>
        </div>

        <!-- Hybrid Referral Banner (Funnel C: Klien Puas -> Partner) -->
        <div v-if="['done', 'paid'].includes(request.status)" class="bg-gradient-to-r from-electric-blue/10 via-primary-fixed/20 to-success-green/10 border border-electric-blue/30 rounded-2xl p-6 sm:p-7 text-center sm:text-left flex flex-col sm:flex-row items-center justify-between gap-5">
          <div>
            <div class="inline-flex items-center gap-1.5 text-xs font-bold text-success-green bg-success-green/10 px-3 py-1 rounded-full mb-2">
              <span class="material-symbols-outlined text-[15px]">monetization_on</span>
              Program Referral Mahasiswa
            </div>
            <h4 class="font-bold text-base sm:text-lg text-on-surface">Punya teman sekelas yang lagi pusing ngoding juga?</h4>
            <p class="text-xs sm:text-sm text-secondary mt-1 max-w-lg">
              Rekomendasikan jokitugasit.my.id ke temanmu dan dapatkan <strong>komisi 10% bersih</strong> langsung ke e-wallet kamu setiap project deal. Tanpa modal, tanpa ikut ngoding.
            </p>
          </div>
          <RouterLink
            to="/partner"
            class="bg-accent-fill text-white font-bold text-xs sm:text-sm px-6 py-3 rounded-xl shadow-md hover:bg-accent-fill transition-all shrink-0 active:scale-95 whitespace-nowrap"
          >
            Daftar Jadi Partner (10%)
          </RouterLink>
        </div>
      </section>
      <section v-else-if="!loading" class="max-w-2xl mx-auto text-center py-8"><span class="material-symbols-outlined text-5xl text-muted">search</span><p class="text-secondary mt-3">Belum ada order yang dicari.</p><button class="mt-5 text-electric-blue font-label-bold text-label-bold hover:underline" @click="router.push('/request')">Kirim request baru →</button></section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
