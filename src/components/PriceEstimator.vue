<script setup>
import { ref, computed } from 'vue'
import { RouterLink } from 'vue-router'
import { waLink } from '../lib/api'

const serviceTypes = [
  {
    id: 'quick_fix',
    name: 'Quick Fix / Debug Error',
    badge: 'Tercepat',
    desc: 'Benerin bug error spesifik, runtime exception, query macet, atau kode mentok ChatGPT.',
    baseMin: 150000,
    baseMax: 300000,
    eta: '1 – 3 Jam',
    icon: 'bug_report',
  },
  {
    id: 'feature',
    name: 'Feature Sprint / CRUD / API',
    badge: 'Populer',
    desc: 'Pembuatan modul fitur baru, integrasi database relasional, payment gateway, atau REST API.',
    baseMin: 500000,
    baseMax: 1200000,
    eta: '1 – 3 Hari',
    icon: 'code',
  },
  {
    id: 'capstone',
    name: 'Skripsi / Capstone / Full App',
    badge: 'Lengkap',
    desc: 'Pendampingan pembuatan aplikasi utuh web/mobile, sistem cerdas AI/ML, sampai siap demo dosen.',
    baseMin: 1500000,
    baseMax: 3500000,
    eta: '1 – 2 Minggu',
    icon: 'school',
  },
]

const techStacks = [
  { id: 'web', name: 'Web (Laravel / React / Vue / PHP)', multiplier: 1.0 },
  { id: 'mobile', name: 'Mobile (Flutter / React Native)', multiplier: 1.15 },
  { id: 'ai', name: 'Python (AI / Machine Learning / Data)', multiplier: 1.2 },
  { id: 'backend', name: 'Backend API & Database (Node / Go / SQL)', multiplier: 1.05 },
  { id: 'desktop', name: 'Desktop (Java / C++ / Python)', multiplier: 1.0 },
]

const urgencies = [
  { id: 'santai', name: 'Santai (> 1 Minggu)', multiplier: 0.95, sub: 'Diskon santai' },
  { id: 'normal', name: 'Normal (3 – 5 Hari)', multiplier: 1.0, sub: 'Jadwal reguler' },
  { id: 'mendesak', name: 'Mendesak (Hari Ini / < 48 Jam)', multiplier: 1.25, sub: 'Prioritas utama' },
]

const addons = [
  {
    id: 'video_walkthrough',
    name: 'Video Walkthrough Kode',
    price: 50000,
    desc: 'Rekaman video penjelasan logika fungsi agar kamu paham saat ditanya dosen.',
    icon: 'smart_display',
  },
  {
    id: 'demo_cheatsheet',
    name: 'Cheatsheet Sidang / Tanya Dosen',
    price: 100000,
    desc: 'Catatan ringkas konsep teknis & prediksi pertanyaan dosen penguji saat demo.',
    icon: 'description',
  },
  {
    id: 'meet_setup',
    name: '1-on-1 Setup via Google Meet',
    price: 75000,
    desc: 'Panduan langsung setup database & run localhost di laptopmu sampai jalan.',
    icon: 'video_camera_front',
  },
]

const selectedService = ref('feature')
const selectedStack = ref('web')
const selectedUrgency = ref('normal')
const selectedAddons = ref(['video_walkthrough'])

function toggleAddon(id) {
  const idx = selectedAddons.value.indexOf(id)
  if (idx >= 0) {
    selectedAddons.value.splice(idx, 1)
  } else {
    selectedAddons.value.push(id)
  }
}

const currentService = computed(() => serviceTypes.find(s => s.id === selectedService.value) || serviceTypes[0])
const currentStack = computed(() => techStacks.find(t => t.id === selectedStack.value) || techStacks[0])
const currentUrgency = computed(() => urgencies.find(u => u.id === selectedUrgency.value) || urgencies[1])

const addonTotal = computed(() => {
  return selectedAddons.value.reduce((sum, id) => {
    const item = addons.find(a => a.id === id)
    return sum + (item ? item.price : 0)
  }, 0)
})

const estimatedMin = computed(() => {
  const base = currentService.value.baseMin * currentStack.value.multiplier * currentUrgency.value.multiplier
  const total = Math.round((base + addonTotal.value) / 10000) * 10000
  return total
})

const estimatedMax = computed(() => {
  const base = currentService.value.baseMax * currentStack.value.multiplier * currentUrgency.value.multiplier
  const total = Math.round((base + addonTotal.value) / 10000) * 10000
  return total
})

const estimatedDp = computed(() => {
  return Math.round(estimatedMin.value / 2 / 10000) * 10000
})

function formatRupiah(num) {
  return 'Rp ' + Number(num).toLocaleString('id-ID')
}

const waMessage = computed(() => {
  const addonNames = selectedAddons.value.map(id => addons.find(a => a.id === id)?.name).filter(Boolean).join(', ')
  return `Halo jokitugasit.my.id, saya sudah cek estimasi di website:
• Layanan: ${currentService.value.name}
• Stack: ${currentStack.value.name}
• Deadline: ${currentUrgency.value.name}
• Add-on: ${addonNames || 'Tanpa Add-on'}
• Estimasi Biaya: ${formatRupiah(estimatedMin.value)} - ${formatRupiah(estimatedMax.value)} (DP 50% ~${formatRupiah(estimatedDp.value)})

Apakah bisa konsultasi detail untuk project saya?`
})
</script>

<template>
  <div class="bg-surface-white rounded-3xl border border-border-subtle shadow-[0_10px_35px_rgba(15,23,42,0.06)] p-5 sm:p-8 md:p-10 max-w-4xl mx-auto">
    <!-- Header -->
    <div class="text-center max-w-2xl mx-auto mb-8">
      <div class="inline-flex items-center gap-2 bg-primary-fixed/40 border border-primary-fixed/50 rounded-full px-3.5 py-1 text-xs text-electric-blue font-semibold mb-3">
        <span class="material-symbols-outlined text-[16px]">calculate</span>
        <span>Kalkulator Estimasi Biaya Transparan</span>
      </div>
      <h2 class="font-display-hero-mobile sm:font-headline-lg text-2xl sm:text-headline-lg font-extrabold text-on-surface mb-2">
        Hitung Estimasi Biaya Project Kamu
      </h2>
      <p class="text-sm sm:text-body-md text-secondary">
        Disesuaikan dengan tingkat kesulitan kode, teknologi, urgensi deadline, dan mentoring pendampingan dosen.
      </p>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
      <!-- Controls Form (Col 7) -->
      <div class="lg:col-span-7 space-y-6">
        <!-- 1. Service Tier -->
        <div>
          <label class="block font-label-bold text-sm text-on-surface mb-2">1. Pilih Tingkat Kebutuhan</label>
          <div class="space-y-2.5">
            <label
              v-for="s in serviceTypes"
              :key="s.id"
              class="flex items-start gap-3 p-3.5 rounded-2xl border transition-all cursor-pointer"
              :class="selectedService === s.id ? 'border-electric-blue bg-primary-fixed/20 shadow-sm' : 'border-border-subtle bg-surface-container-lowest hover:border-outline-variant'"
            >
              <input v-model="selectedService" type="radio" :value="s.id" class="sr-only" />
              <div
                class="w-10 h-10 rounded-xl flex items-center justify-center shrink-0 mt-0.5"
                :class="selectedService === s.id ? 'bg-electric-blue text-white' : 'bg-surface-container-high text-secondary'"
              >
                <span class="material-symbols-outlined text-[20px]">{{ s.icon }}</span>
              </div>
              <div class="flex-1">
                <div class="flex items-center justify-between">
                  <span class="font-bold text-sm text-on-surface">{{ s.name }}</span>
                  <span class="text-[10px] uppercase font-bold px-2 py-0.5 rounded-md" :class="selectedService === s.id ? 'bg-electric-blue text-white' : 'bg-surface-container-high text-secondary'">{{ s.badge }}</span>
                </div>
                <p class="text-xs text-secondary mt-1 leading-relaxed">{{ s.desc }}</p>
              </div>
            </label>
          </div>
        </div>

        <!-- 2. Tech Stack -->
        <div>
          <label class="block font-label-bold text-sm text-on-surface mb-2">2. Teknologi / Bahasa Pemrograman</label>
          <div class="relative">
            <select
              v-model="selectedStack"
              class="w-full rounded-xl border border-border-subtle bg-surface-container-lowest px-4 py-3 text-sm font-medium text-on-surface focus:border-electric-blue focus:ring-1 focus:ring-electric-blue outline-none appearance-none"
            >
              <option v-for="t in techStacks" :key="t.id" :value="t.id">{{ t.name }}</option>
            </select>
            <span class="material-symbols-outlined absolute right-3.5 top-1/2 -translate-y-1/2 text-secondary pointer-events-none">expand_more</span>
          </div>
        </div>

        <!-- 3. Urgency -->
        <div>
          <label class="block font-label-bold text-sm text-on-surface mb-2">3. Target Deadline</label>
          <div class="grid grid-cols-3 gap-2 sm:gap-2.5">
            <label
              v-for="u in urgencies"
              :key="u.id"
              class="flex flex-col items-center justify-center p-2.5 sm:p-3 rounded-xl border text-center transition-all cursor-pointer"
              :class="selectedUrgency === u.id ? 'border-electric-blue bg-primary-fixed/25 text-electric-blue font-bold shadow-sm' : 'border-border-subtle bg-surface-container-lowest text-secondary'"
            >
              <input v-model="selectedUrgency" type="radio" :value="u.id" class="sr-only" />
              <span class="text-xs leading-tight">{{ u.name.split(' (')[0] }}</span>
              <span class="text-[10px] opacity-75 mt-0.5">{{ u.sub }}</span>
            </label>
          </div>
        </div>

        <!-- 4. Add-ons -->
        <div>
          <label class="block font-label-bold text-sm text-on-surface mb-2">
            4. Pendampingan & Add-On Persiapan Dosen
            <span class="text-xs text-secondary font-normal">(Opsional)</span>
          </label>
          <div class="space-y-2">
            <div
              v-for="a in addons"
              :key="a.id"
              @click="toggleAddon(a.id)"
              class="flex items-start gap-3 p-3 rounded-xl border transition-all cursor-pointer"
              :class="selectedAddons.includes(a.id) ? 'border-success-green bg-success-green/5' : 'border-border-subtle bg-surface-container-lowest hover:border-outline-variant'"
            >
              <div
                class="w-5 h-5 rounded-md border flex items-center justify-center mt-0.5 shrink-0 transition-colors"
                :class="selectedAddons.includes(a.id) ? 'bg-success-green border-success-green text-white' : 'border-border-subtle bg-surface-white'"
              >
                <span v-if="selectedAddons.includes(a.id)" class="material-symbols-outlined text-[14px]">check</span>
              </div>
              <div class="flex-1 text-xs">
                <div class="flex items-center justify-between">
                  <span class="font-bold text-on-surface">{{ a.name }}</span>
                  <span class="font-extrabold text-electric-blue">+{{ formatRupiah(a.price) }}</span>
                </div>
                <p class="text-secondary mt-0.5 leading-relaxed">{{ a.desc }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Result Card (Col 5) -->
      <div class="lg:col-span-5 bg-surface-container-low rounded-2xl p-6 sm:p-7 border border-border-subtle/80 flex flex-col justify-between sticky top-20 shadow-sm">
        <div>
          <div class="flex items-center justify-between pb-4 border-b border-border-subtle">
            <span class="text-xs font-bold uppercase tracking-wider text-secondary">Estimasi Biaya Transparan</span>
            <span class="inline-flex items-center gap-1 text-[11px] font-semibold text-success-green bg-success-green/10 px-2 py-0.5 rounded-full">
              <span class="material-symbols-outlined text-[13px]">verified</span>
              Garansi Jalan
            </span>
          </div>

          <!-- Price Range -->
          <div class="py-5">
            <div class="text-xs text-secondary mb-1">Rentang Estimasi Investasi:</div>
            <div class="text-2xl sm:text-3xl font-extrabold text-electric-blue tracking-tight">
              {{ formatRupiah(estimatedMin) }}
              <span class="text-base text-secondary font-medium">s/d</span>
            </div>
            <div class="text-2xl sm:text-3xl font-extrabold text-on-surface tracking-tight mt-0.5">
              {{ formatRupiah(estimatedMax) }}
            </div>
            <div class="inline-flex items-center gap-1.5 mt-3 bg-surface-white border border-border-subtle px-3 py-1.5 rounded-lg text-xs text-on-surface-variant shadow-xs">
              <span class="material-symbols-outlined text-[16px] text-electric-blue">payments</span>
              <span>DP Mulai <strong>50% (~{{ formatRupiah(estimatedDp) }})</strong> saat mulai pengerjaan</span>
            </div>
          </div>

          <!-- Scope Summary -->
          <div class="space-y-2 py-4 border-t border-border-subtle text-xs">
            <div class="flex justify-between text-secondary">
              <span>Paket:</span>
              <span class="font-semibold text-on-surface text-right">{{ currentService.name }}</span>
            </div>
            <div class="flex justify-between text-secondary">
              <span>Estimasi Waktu:</span>
              <span class="font-semibold text-on-surface">{{ currentService.eta }}</span>
            </div>
            <div class="flex justify-between text-secondary">
              <span>Add-on Terpilih:</span>
              <span class="font-semibold text-on-surface">{{ selectedAddons.length }} item (+{{ formatRupiah(addonTotal) }})</span>
            </div>
            <div class="flex justify-between text-secondary">
              <span>Garansi:</span>
              <span class="font-semibold text-success-green">Free Konsul Demo Dosen</span>
            </div>
          </div>
        </div>

        <!-- Action CTAs -->
        <div class="space-y-2.5 pt-5 border-t border-border-subtle">
          <a
            :href="waLink('6285166337257', waMessage)"
            target="_blank"
            rel="noopener"
            class="w-full bg-electric-blue text-white font-label-bold text-label-bold py-3.5 px-4 rounded-xl flex items-center justify-center gap-2 hover:bg-primary transition-all shadow-md active:scale-95 text-sm"
          >
            <span class="material-symbols-outlined text-[20px]" style="font-variation-settings: 'FILL' 1">chat</span>
            Konsultasikan via WhatsApp
          </a>

          <RouterLink
            :to="{ path: '/request', query: { category: currentService.id === 'quick_fix' ? 'debug' : currentService.id === 'capstone' ? 'skripsi' : 'web' } }"
            class="w-full bg-surface-white border-2 border-border-subtle text-on-surface font-label-bold text-label-bold py-3 px-4 rounded-xl flex items-center justify-center gap-1.5 hover:border-electric-blue hover:text-electric-blue transition-all active:scale-95 text-xs text-center"
          >
            <span class="material-symbols-outlined text-[16px]">edit_document</span>
            Kirim Detail ke Form Order
          </RouterLink>
          <p class="text-[11px] text-center text-secondary pt-1">
            Tanpa komitmen bayar. Cek kecocokan kode dulu secara gratis.
          </p>
        </div>
      </div>
    </div>
  </div>
</template>
