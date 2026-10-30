<script setup>
import { ref } from 'vue'
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo jokitugasit.my.id, saya mau diskusi harga project.'

/**
 * Kartu paket sengaja TANPA nominal.
 * Yang ditampilkan hanya tingkat kesulitan dan estimasi waktu —
 * dua hal yang bisa dijawab jujur tanpa mematok angka di muka.
 * Nominal selalu hasil kesepakatan lewat chat.
 */
const packages = [
  {
    icon: 'build', name: 'Quick Fix', popular: false,
    desc: 'Beresin error kecil, setup environment, atau bug ringan yang bikin stuck berjam-jam.',
    level: 'Ringan', eta: '± 1 hari',
    features: ['1 bug / error ringan', 'Setup environment', 'Revisi sekali', 'Cepat selesai'],
  },
  {
    icon: 'bug_report', name: 'Debugging', popular: true,
    desc: 'Penelusuran error kompleks, logic flow yang kacau, atau integrasi API yang gagal.',
    level: 'Sedang', eta: '1 – 3 hari',
    features: ['Error kompleks & logic flow', 'Integrasi API gagal', 'Analisis akar masalah', 'Revisi 2x'],
  },
  {
    icon: 'smart_toy', name: 'AI Code Rescue', popular: false,
    desc: 'Rapihin kode hasil generate AI yang error, optimize logic, dan kasih komentar biar dosen percaya.',
    level: 'Sedang', eta: '2 – 4 hari',
    features: ['Kode AI yang error', 'Optimasi logic', 'Tambahan komentar', 'Refactor rapi'],
  },
  {
    icon: 'rocket_launch', name: 'Full Support', popular: false,
    desc: 'Bimbingan dari nol sampai jalan. Bikin fitur kompleks, integrasi database, deploy ke server.',
    level: 'Berat', eta: '1 minggu+',
    features: ['Fitur kompleks', 'Integrasi database', 'Deploy ke server', 'Pendampingan penuh'],
  },
]

const budgetForm = ref({ budget: '', problem: '' })
const budgetMsg = ref('')

function submitBudget() {
  if (!budgetForm.value.budget.trim() || !budgetForm.value.problem.trim()) {
    budgetMsg.value = 'Isi budget dan cerita masalahnya dulu ya.'
    return
  }
  const text = `Halo jokitugasit.my.id, budget saya Rp${budgetForm.value.budget.trim()}. ${budgetForm.value.problem.trim()}`
  window.open(waLink('6285166337257', text), '_blank')
  budgetMsg.value = ''
}
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Hero -->
      <section class="text-center max-w-3xl mx-auto mb-10">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-1.5 shadow-sm mb-4">
          <span class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse-slow"></span>
          <span class="font-label-sm text-label-sm text-secondary">Engineer Siap Bantu</span>
        </div>
        <h1 class="font-display-hero-mobile md:font-display-hero text-display-hero-mobile md:text-display-hero font-bold text-on-surface mb-4">
          Nggak Ada Harga Mahal,<br /><span class="text-electric-blue">Ada Harga yang Disepakati.</span>
        </h1>
        <p class="font-body-lg text-body-lg text-on-surface-variant max-w-xl mx-auto mb-7">
          Kami sengaja nggak pasang angka di sini. Tiap tugas beda tingkat kesulitannya, dan kami nggak mau kamu kaget di akhir. Ceritain dulu masalah dan budget kamu — engineer yang nentuin, kamu yang setuju.
        </p>
        <a href="#budget" class="inline-flex items-center gap-2 bg-electric-blue text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl shadow-md hover:bg-primary transition-colors">
          <span class="material-symbols-outlined">chat</span>
          Ceritain Budget Kamu
        </a>
      </section>

      <!-- Budget Sendiri — pintu utama, sengaja di atas -->
      <section id="budget" class="bg-surface-white rounded-2xl border border-border-subtle shadow-sm p-6 md:p-10 max-w-2xl mx-auto mb-16 scroll-mt-20">
        <div class="text-center mb-6">
          <div class="inline-flex items-center gap-2 bg-primary-fixed/40 text-electric-blue rounded-full px-3 py-1 mb-3">
            <span class="material-symbols-outlined text-[16px]" aria-hidden="true">savings</span>
            <span class="text-xs font-bold uppercase tracking-wide">Tanpa Komitmen</span>
          </div>
          <h2 class="font-headline-lg text-headline-lg font-bold text-on-surface mb-2">Punya Budget Sendiri?</h2>
          <p class="text-sm text-secondary max-w-lg mx-auto">
            Sebutin aja budget kamu — berapa pun itu. Engineer kami akan bantu sesuaikan scope pekerjaan dengan dana yang ada, biar tugas tetap aman tanpa bikin kantong bolong.
          </p>
        </div>
        <form class="space-y-4" @submit.prevent="submitBudget">
          <div>
            <label class="block font-label-bold text-label-bold text-on-background mb-1.5" for="budget">Berapa Budget Kamu?</label>
            <div class="relative">
              <span class="absolute inset-y-0 left-0 flex items-center pl-4 text-secondary font-body-md">Rp</span>
              <input id="budget" v-model="budgetForm.budget" type="number" min="0" placeholder="100000"
                class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest pl-10 pr-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none" />
            </div>
            <p class="mt-1.5 text-xs text-secondary">Isi seadanya aja. Kalau belum tau, kosongin dulu dan langsung chat.</p>
          </div>
          <div>
            <label class="block font-label-bold text-label-bold text-on-background mb-1.5" for="problem">Ceritain Dikit Masalahnya</label>
            <textarea id="problem" v-model="budgetForm.problem" rows="3" placeholder="Contoh: tugas CRUD PHP yang error, deadline 3 hari lagi..."
              class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-body-md focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none resize-none"></textarea>
          </div>
          <div v-if="budgetMsg" class="bg-error-container text-on-error-container rounded-lg px-4 py-3 font-body-md text-body-md">{{ budgetMsg }}</div>
          <button type="submit" class="w-full bg-electric-blue text-white font-label-bold text-label-bold py-3.5 rounded-xl hover:bg-primary transition-colors shadow-md">
            Chat Engineer, Gratis
          </button>
          <p class="text-center text-xs text-secondary">Langsung ke WhatsApp. Nggak ada biaya konsultasi, nggak ada paksaan lanjut.</p>
        </form>
      </section>

      <!-- Section Title for Packages -->
      <div class="text-center max-w-xl mx-auto mb-8">
        <h2 class="font-headline-lg text-headline-lg font-bold text-on-surface mb-2">Pilihan Paket Standar</h2>
        <p class="text-sm text-secondary">Gambaran lingkup kerja dan waktu pengerjaan. Nominalnya kita omongin setelah engineer lihat kode kamu.</p>
      </div>

      <!-- Pricing Cards -->
      <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-10">
        <div v-for="pkg in packages" :key="pkg.name"
          class="relative bg-surface-white rounded-2xl p-6 border shadow-sm flex flex-col transition-all hover:shadow-md"
          :class="pkg.popular ? 'border-electric-blue ring-2 ring-electric-blue/15' : 'border-border-subtle'">
          <span v-if="pkg.popular" class="absolute -top-3 left-1/2 -translate-x-1/2 bg-electric-blue text-white text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full whitespace-nowrap">Paling Laku</span>
          <span class="w-11 h-11 rounded-xl flex items-center justify-center mb-4" :class="pkg.popular ? 'bg-electric-blue text-white' : 'bg-primary-fixed/40 text-electric-blue'">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">{{ pkg.icon }}</span>
          </span>
          <h2 class="font-headline-md text-headline-md font-bold text-on-surface mb-1">{{ pkg.name }}</h2>
          <p class="text-sm text-secondary mb-4 leading-6 flex-grow">{{ pkg.desc }}</p>
          <div class="mb-5 flex flex-wrap items-center gap-2">
            <span class="inline-flex items-center gap-1.5 rounded-full bg-primary-fixed/40 px-3 py-1 text-xs font-semibold text-electric-blue">
              <span class="material-symbols-outlined text-[14px]" aria-hidden="true">speed</span>{{ pkg.level }}
            </span>
            <span class="inline-flex items-center gap-1.5 rounded-full bg-surface-container-lowest border border-border-subtle px-3 py-1 text-xs font-semibold text-secondary">
              <span class="material-symbols-outlined text-[14px]" aria-hidden="true">schedule</span>{{ pkg.eta }}
            </span>
          </div>
          <ul class="space-y-2.5 mb-6">
            <li v-for="f in pkg.features" :key="f" class="flex items-start gap-2 text-sm text-on-surface-variant">
              <span class="material-symbols-outlined text-[16px] text-success-green shrink-0">check_circle</span>
              {{ f }}
            </li>
          </ul>
          <a :href="waLink('6285166337257', `Halo, saya mau paket ${pkg.name}. ${pkg.desc}`)" target="_blank" rel="noopener"
            class="mt-auto w-full text-center py-3 rounded-xl font-label-bold text-label-bold transition-colors"
            :class="pkg.popular ? 'bg-electric-blue text-white hover:bg-primary' : 'border-2 border-electric-blue text-electric-blue hover:bg-primary-fixed/20'">
            Tanya Paket Ini
          </a>
        </div>
      </section>

      <!-- Penutup: tegaskan tidak ada angka di muka -->
      <p class="text-center text-sm text-secondary max-w-xl mx-auto">
        Nominal selalu disepakati lewat chat sebelum kerja dimulai — tanpa biaya tersembunyi, tanpa tagihan kejutan.
        <RouterLink to="/request" class="text-electric-blue font-semibold hover:underline">Isi brief lengkap</RouterLink>
        kalau kamu sudah siap.
      </p>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
