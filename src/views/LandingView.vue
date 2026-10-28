<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo jokitugasit.my.id, saya butuh bantuan untuk project IT saya.'

import { ref, onMounted, onBeforeUnmount } from 'vue'

const solvedProjects = [
  {
    icon: 'integration_instructions', title: 'Perbaikan Tampilan Flutter', ticket: 'Tiket #8892',
    deadline: 'Besok', deadlineColor: 'bg-error-container text-error',
    tags: ['Flutter', 'Firebase', 'Manajemen State'],
    desc: '"Tampilan berantakan di layar kecil saat keyboard muncul. Butuh bantuan agar elemen bisa diatur dalam scroll view."',
    status: 'Siap kamu cek', progress: 100, orderNo: 'TEST-REVIEW',
  },
  {
    icon: 'web', title: 'Landing Page Skripsi', ticket: 'Tiket #8901',
    deadline: 'Selesai', deadlineColor: 'bg-success-green/10 text-success-green',
    tags: ['HTML/CSS', 'React', 'Responsive'],
    desc: '"Perlu landing page untuk proposal skripsi, clean dan mobile-friendly, buat demo besok pagi."',
    status: 'Selesai & Terkirim', progress: 100, orderNo: 'TEST-DONE',
  },
  {
    icon: 'smartphone', title: 'Aplikasi Catatan Kuliah', ticket: 'Tiket #8874',
    deadline: 'Selesai', deadlineColor: 'bg-success-green/10 text-success-green',
    tags: ['Flutter', 'SQLite', 'UI/UX'],
    desc: '"Aplikasi catatan kuliah offline dengan reminder tugas, biar nggak ada deadline yang kelewat."',
    status: 'Selesai & Terkirim', progress: 100, orderNo: 'TEST-DONE',
  },
]

const activeSlide = ref(0)
let slideTimer = null

function nextSlide() {
  activeSlide.value = (activeSlide.value + 1) % solvedProjects.length
}
function goSlide(i) {
  activeSlide.value = i
}

onMounted(() => {
  slideTimer = setInterval(nextSlide, 4000)
})
onBeforeUnmount(() => {
  if (slideTimer) clearInterval(slideTimer)
})
</script>

<template>
  <div class="bg-background text-on-surface font-body-md antialiased min-h-screen flex flex-col relative overflow-x-hidden">
    <TopAppBar />

    <main class="flex-grow flex flex-col gap-section-gap-mobile md:gap-section-gap-desktop pb-section-gap-mobile md:pb-section-gap-desktop w-full">
      <!-- Hero Section -->
      <section class="relative pt-12 md:pt-24 px-gutter max-w-container-max-width mx-auto w-full flex flex-col md:flex-row items-center gap-12">
        <div class="absolute -top-20 -left-20 w-96 h-96 bg-electric-blue/10 rounded-full blur-3xl -z-10 mix-blend-multiply"></div>

        <div class="flex-1 flex flex-col gap-6 items-start z-10">
          <div class="flex items-center gap-3 flex-wrap">
            <div class="flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-1.5 shadow-sm">
              <div class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse-slow"></div>
              <span class="font-label-sm text-label-sm text-secondary">Engineer siap bantu sekarang</span>
            </div>
            <div class="flex items-center gap-1.5 bg-primary-fixed/40 border border-primary-fixed/50 rounded-full px-3 py-1.5">
              <span class="material-symbols-outlined text-[14px] text-electric-blue">person_off</span>
              <span class="font-label-sm text-label-sm text-on-surface-variant">Tanpa Daftar</span>
            </div>
          </div>
          <h1 class="font-display-hero-mobile text-display-hero-mobile md:font-display-hero md:text-display-hero text-on-surface">
            Tugas ngoding apa pun,<br />
            <span class="text-electric-blue">kirim dulu.</span>
          </h1>
          <p class="font-body-lg text-body-lg text-on-surface-variant max-w-lg">
            Mentok bikin website, aplikasi, atau error kode yang bikin pusing? Ceritakan saja. Kami bantu beresin dengan cepat, jelas, dan tetap ramah di kantong mahasiswa.
          </p>
          <div class="flex flex-col sm:flex-row gap-4 w-full sm:w-auto mt-4">
            <RouterLink
              to="/request"
              class="bg-electric-blue text-surface-white font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-primary transition-all duration-200 active:scale-95 shadow-lg flex items-center justify-center gap-2 h-[52px]"
            >
              <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">rocket_launch</span>
              Cek Dulu Gratis
            </RouterLink>
            <a
              :href="waLink('6285166337257', WA_TEXT)"
              target="_blank"
              rel="noopener"
              class="bg-surface-white border-2 border-border-subtle text-on-surface font-label-bold text-label-bold px-8 py-4 rounded-xl hover:border-electric-blue hover:text-electric-blue transition-all duration-200 active:scale-95 shadow-sm flex items-center justify-center gap-2 h-[52px]"
            >
              <span class="material-symbols-outlined text-[#25D366]" style="font-variation-settings: 'FILL' 1">chat</span>
              Tanya via WhatsApp
            </a>
          </div>
          <div class="flex items-center gap-4 mt-3 flex-wrap">
            <div class="flex items-center gap-1.5 text-on-surface-variant">
              <span class="material-symbols-outlined text-[16px] text-success-green">lock</span>
              <span class="text-[11px] font-medium">100% Privasi</span>
            </div>
            <div class="w-1 h-1 rounded-full bg-border-subtle"></div>
            <div class="flex items-center gap-1.5 text-on-surface-variant">
              <span class="material-symbols-outlined text-[16px] text-electric-blue">person_off</span>
              <span class="text-[11px] font-medium">Tanpa Login</span>
            </div>
            <div class="w-1 h-1 rounded-full bg-border-subtle"></div>
            <div class="flex items-center gap-1.5 text-on-surface-variant">
              <span class="material-symbols-outlined text-[16px] text-electric-blue">bolt</span>
              <span class="text-[11px] font-medium">Langsung ke Engineer</span>
            </div>
          </div>
          <div class="flex items-center gap-3 mt-4">
            <div class="flex -space-x-3">
              <img
                class="w-10 h-10 rounded-full border-2 border-surface-white object-cover"
                alt="Mahasiswa pria"
                width="40"
                height="40"
                loading="lazy"
                decoding="async"
                src="https://lh3.googleusercontent.com/aida-public/AB6AXuAVAjGHtHooawJHDgPHrFwfL060vMliRPwVusWrlQ1oeAsqsWbjMzAinuAREcKvX-VtluVNWJI9hPP-cWhXemI5hTygcT9SD_KksjarTFDTVe3ntYoD8-IxcjBzOqZgPZCPIoY-mTZUlvoOk30JwxRi5O2n7ddDP8G359cYao10efZn0hAM_QRH4Y7x30_aZ7I--nmzIHFAGqmliIyi4Og1bwj7-oE2bWAiZRsSe14w40z8FhSudpz5"
              />
              <img
                class="w-10 h-10 rounded-full border-2 border-surface-white object-cover"
                alt="Mahasiswi"
                width="40"
                height="40"
                loading="lazy"
                decoding="async"
                src="https://lh3.googleusercontent.com/aida-public/AB6AXuCqT7ciwFPpX_nkc9ZhGHL9m925emBY7pgdJE_BtnU7ntr5ejbmY5M5MJFTVJO-7Ch_qUTXxJcfimyWxQIDKAmOujpShsvtOx34f50jCqLVjLfxNqJvuRi1hl9EGO5w5Ystu6alyTI_GFxReKrhVirsMDVkaS9eM9cjxPUmfrti6DUFT48Kzbcb6ztqy3oyzMHq6EFSu22ZAA0473pIflYvKpFeY6tckQw0SdLmB0jALUGmq9OPaYAZ"
              />
              <div class="w-10 h-10 rounded-full border-2 border-surface-white bg-surface-container-high flex items-center justify-center text-label-sm font-label-sm text-secondary">
                +1k
              </div>
            </div>
            <span class="font-label-sm text-label-sm text-secondary">Project mahasiswa beres</span>
          </div>
        </div>

        <!-- Hero Visual (Carousel Project Selesai) -->
        <div class="flex-1 w-full max-w-md relative z-10">
          <div class="absolute -bottom-10 -right-10 w-64 h-64 bg-primary-fixed-dim/30 rounded-full blur-2xl -z-10"></div>
          <div class="relative overflow-hidden rounded-2xl shadow-[0px_10px_30px_rgba(15,23,42,0.12)] border border-border-subtle bg-surface-white">
            <!-- Slides -->
            <div class="flex transition-transform duration-500 ease-out" :style="{ transform: `translateX(-${activeSlide * 100}%)` }">
              <div
                v-for="(proj, i) in solvedProjects"
                :key="i"
                class="w-full shrink-0 p-6 flex flex-col gap-5"
              >
                <div class="flex justify-between items-start">
                  <div class="flex items-center gap-3">
                    <div class="w-12 h-12 bg-primary-fixed/50 rounded-xl flex items-center justify-center text-electric-blue">
                      <span class="material-symbols-outlined text-3xl" style="font-variation-settings: 'FILL' 1">{{ proj.icon }}</span>
                    </div>
                    <div>
                      <h3 class="font-label-bold text-label-bold text-on-surface">{{ proj.title }}</h3>
                      <p class="font-label-sm text-label-sm text-secondary mt-1">{{ proj.ticket }}</p>
                    </div>
                  </div>
                  <span class="px-2 py-1 rounded-md font-label-sm text-label-sm flex items-center gap-1" :class="proj.deadlineColor">
                    <span class="material-symbols-outlined text-[14px]">timer</span>
                    {{ proj.deadline }}
                  </span>
                </div>
                <div class="space-y-3">
                  <div class="flex flex-wrap gap-2">
                    <span v-for="t in proj.tags" :key="t" class="bg-surface-container-high text-on-secondary-container px-2.5 py-1 rounded-full font-label-sm text-label-sm">{{ t }}</span>
                  </div>
                  <p class="font-body-md text-body-md text-on-surface-variant text-sm leading-6">{{ proj.desc }}</p>
                </div>
                <div class="bg-surface-container-low rounded-xl p-4 border border-border-subtle/50">
                  <div class="flex justify-between items-center mb-2">
                    <span class="font-label-bold text-label-bold text-secondary">Status Pengerjaan</span>
                    <span class="font-label-bold text-label-bold text-success-green flex items-center gap-1">
                      <span class="material-symbols-outlined text-[16px]">check_circle</span>
                      {{ proj.status }}
                    </span>
                  </div>
                  <div class="w-full bg-surface-dim rounded-full h-2 overflow-hidden">
                    <div class="bg-success-green h-full rounded-full relative" :style="{ width: proj.progress + '%' }">
                      <div class="absolute inset-0 bg-white/20 animate-pulse"></div>
                    </div>
                  </div>
                </div>
                <RouterLink
                  :to="`/track/${proj.orderNo}`"
                  class="w-full bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold py-3 rounded-xl hover:bg-primary-fixed/20 transition-colors h-[44px] text-center"
                >
                  Lihat Hasil Project
                </RouterLink>
              </div>
            </div>

            <!-- Controls (indikator saja) -->
            <div class="flex items-center justify-center px-5 py-3 border-t border-border-subtle bg-surface-container-lowest/80">
              <div class="flex items-center gap-1.5">
                <button
                  v-for="(_, i) in solvedProjects"
                  :key="i"
                  @click="goSlide(i)"
                  class="h-2 rounded-full transition-all duration-300"
                  :class="i === activeSlide ? 'w-6 bg-electric-blue' : 'w-2 bg-border-subtle hover:bg-outline-variant'"
                  :aria-label="`Ke project ${i + 1}`"
                ></button>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Pricing Teaser Section -->
      <section class="bg-surface-white border-y border-border-subtle py-8">
        <div class="px-gutter max-w-container-max-width mx-auto flex flex-col md:flex-row items-center justify-between gap-6">
          <div class="flex items-center gap-4">
            <div class="w-14 h-14 bg-surface-container-low rounded-full flex items-center justify-center text-electric-blue">
              <span class="material-symbols-outlined text-3xl" style="font-variation-settings: 'FILL' 1">payments</span>
            </div>
            <div>
              <h3 class="font-headline-md text-headline-md text-on-surface">Mulai dari <span class="text-electric-blue">Rp10k</span></h3>
              <p class="font-body-md text-body-md text-on-surface-variant">Harga mahasiswa, kualitas tetap profesional.</p>
            </div>
          </div>
          <div class="flex flex-wrap gap-3">
            <span class="flex items-center gap-1 font-label-bold text-label-bold text-secondary bg-surface-container-lowest px-3 py-1.5 border border-border-subtle rounded-full shadow-sm">
              <span class="material-symbols-outlined text-[16px] text-success-green">check</span> Benerin Error
            </span>
            <span class="flex items-center gap-1 font-label-bold text-label-bold text-secondary bg-surface-container-lowest px-3 py-1.5 border border-border-subtle rounded-full shadow-sm">
              <span class="material-symbols-outlined text-[16px] text-success-green">check</span> Bikin Fitur
            </span>
            <span class="flex items-center gap-1 font-label-bold text-label-bold text-secondary bg-surface-container-lowest px-3 py-1.5 border border-border-subtle rounded-full shadow-sm">
              <span class="material-symbols-outlined text-[16px] text-success-green">check</span> Bikin Aplikasi
            </span>
          </div>
        </div>
      </section>

      <!-- Categories Section -->
      <section class="px-gutter max-w-container-max-width mx-auto w-full flex flex-col gap-8" id="services">
        <div class="text-center max-w-2xl mx-auto">
          <h2 class="font-headline-lg text-headline-lg text-on-surface mb-4">Lagi mentok di bagian mana?</h2>
          <p class="font-body-md text-body-md text-on-surface-variant">Mulai dari error kecil sampai project kuliah yang bikin begadang, ceritakan kebutuhanmu di sini.</p>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <!-- Web Dev Card -->
          <div class="group bg-surface-white border border-border-subtle rounded-2xl p-6 shadow-[0px_4px_20px_rgba(15,23,42,0.04)] hover:shadow-[0px_8px_30px_rgba(15,23,42,0.08)] hover:border-electric-blue transition-all duration-300 flex flex-col h-full col-span-1 md:col-span-2 relative overflow-hidden">
            <div class="absolute top-0 right-0 w-40 h-40 bg-electric-blue/5 rounded-bl-full -z-10 transition-transform group-hover:scale-110"></div>
            <div class="flex justify-between items-start mb-6">
              <div class="w-12 h-12 bg-primary-fixed/50 rounded-xl flex items-center justify-center text-electric-blue">
                <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">language</span>
              </div>
              <span class="material-symbols-outlined text-secondary group-hover:text-electric-blue transition-colors">arrow_forward</span>
            </div>
            <h3 class="font-headline-md text-headline-md text-on-surface mb-2">Bikin Website</h3>
            <p class="font-body-md text-body-md text-on-surface-variant mb-6 flex-grow">
              Dari landing page sederhana, dashboard admin yang kompleks, hingga slicing Figma ke HTML/React.
            </p>
            <div class="flex flex-wrap gap-2 mt-auto">
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">React</span>
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">Next.js</span>
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">PHP</span>
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">Laravel</span>
            </div>
          </div>

          <!-- AI Rescue Card -->
          <div class="group bg-surface-white border border-border-subtle rounded-2xl p-6 shadow-[0px_4px_20px_rgba(15,23,42,0.04)] hover:shadow-[0px_8px_30px_rgba(15,23,42,0.08)] hover:border-urgency-red transition-all duration-300 flex flex-col h-full relative overflow-hidden">
            <div class="absolute top-0 right-0 w-32 h-32 bg-urgency-red/5 rounded-bl-full -z-10 transition-transform group-hover:scale-110"></div>
            <div class="flex justify-between items-start mb-6">
              <div class="w-12 h-12 bg-error-container rounded-xl flex items-center justify-center text-urgency-red">
                <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">sos</span>
              </div>
              <span class="bg-urgency-red/10 text-urgency-red px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider">Popular</span>
            </div>
            <h3 class="font-headline-md text-headline-md text-on-surface mb-2">Selamatkan Kode Error</h3>
            <p class="font-body-md text-body-md text-on-surface-variant mb-6 flex-grow">
              Kode dari ChatGPT malah makin error? Kami bantu cari akar masalahnya sampai bisa jalan.
            </p>
            <div class="flex flex-wrap gap-2 mt-auto">
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">Debug</span>
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">Refactor</span>
            </div>
          </div>

          <!-- Bikin Aplikasi Mobile Card -->
          <div class="group bg-surface-white border border-border-subtle rounded-2xl p-6 shadow-[0px_4px_20px_rgba(15,23,42,0.04)] hover:shadow-[0px_8px_30px_rgba(15,23,42,0.08)] hover:border-electric-blue transition-all duration-300 flex flex-col h-full relative overflow-hidden">
            <div class="absolute top-0 right-0 w-32 h-32 bg-primary-fixed-dim/10 rounded-bl-full -z-10 transition-transform group-hover:scale-110"></div>
            <div class="flex justify-between items-start mb-6">
              <div class="w-12 h-12 bg-primary-fixed/50 rounded-xl flex items-center justify-center text-electric-blue">
                <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">smartphone</span>
              </div>
            </div>
            <h3 class="font-headline-md text-headline-md text-on-surface mb-2">Bikin Aplikasi Mobile</h3>
            <p class="font-body-md text-body-md text-on-surface-variant mb-6 flex-grow">
              Aplikasi Android atau iOS yang rapi untuk tugas akhir dan project kuliah.
            </p>
            <div class="flex flex-wrap gap-2 mt-auto">
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">Flutter</span>
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">React Native</span>
            </div>
          </div>

          <!-- Database & API Card -->
          <div class="group bg-surface-white border border-border-subtle rounded-2xl p-6 shadow-[0px_4px_20px_rgba(15,23,42,0.04)] hover:shadow-[0px_8px_30px_rgba(15,23,42,0.08)] hover:border-electric-blue transition-all duration-300 flex flex-col h-full relative overflow-hidden">
            <div class="absolute top-0 right-0 w-32 h-32 bg-tertiary-fixed-dim/10 rounded-bl-full -z-10 transition-transform group-hover:scale-110"></div>
            <div class="flex justify-between items-start mb-6">
              <div class="w-12 h-12 bg-tertiary-fixed/30 rounded-xl flex items-center justify-center text-tertiary">
                <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">database</span>
              </div>
            </div>
            <h3 class="font-headline-md text-headline-md text-on-surface mb-2">Database &amp; API</h3>
            <p class="font-body-md text-body-md text-on-surface-variant mb-6 flex-grow">
              Bantu menyusun database dan API supaya project-mu tidak berantakan saat dikembangkan.
            </p>
            <div class="flex flex-wrap gap-2 mt-auto">
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">MySQL</span>
              <span class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">Node.js</span>
            </div>
          </div>

          <!-- Problem Card (Call to Action) -->
          <div class="bg-electric-blue rounded-2xl p-6 shadow-lg flex flex-col items-center justify-center text-center h-full relative overflow-hidden group">
            <div class="absolute inset-0 bg-primary opacity-0 group-hover:opacity-100 transition-opacity duration-300 -z-10"></div>
            <span class="material-symbols-outlined text-surface-white text-4xl mb-4" style="font-variation-settings: 'FILL' 1">help</span>
            <h3 class="font-headline-md text-headline-md text-surface-white mb-2">Bingung Mulai dari Mana?</h3>
            <p class="font-body-md text-body-md text-on-primary-container mb-6 opacity-90">
              Tidak perlu jago menjelaskan teknis. Ceritakan masalahnya, kami bantu cari solusinya.
            </p>
            <RouterLink
              to="/request"
              class="bg-surface-white text-electric-blue font-label-bold text-label-bold px-6 py-3 rounded-xl hover:bg-surface-container-lowest transition-colors shadow-md h-[44px] w-full flex items-center justify-center"
            >
              Konsultasi Gratis
            </RouterLink>
          </div>
        </div>
      </section>

      <!-- Process Section -->
      <section class="bg-surface-container py-16 px-gutter" id="how-it-works">
        <div class="max-w-container-max-width mx-auto">
          <div class="text-center max-w-2xl mx-auto mb-12">
            <h2 class="font-headline-lg text-headline-lg text-on-surface mb-4">Alurnya sesimpel ini.</h2>
            <p class="font-body-md text-body-md text-on-surface-variant">Tidak perlu ribet dan tidak ada biaya tersembunyi. Semua jelas dari awal sampai selesai.</p>
          </div>
          <div class="flex flex-col lg:flex-row gap-6 relative">
            <div class="hidden lg:block absolute top-1/2 left-8 right-8 h-1 bg-border-subtle -translate-y-1/2 z-0"></div>

            <div class="flex-1 bg-surface-white rounded-2xl p-6 shadow-sm border border-border-subtle relative z-10 flex flex-col items-center text-center hover:-translate-y-1 transition-transform duration-300">
              <div class="w-12 h-12 bg-primary-fixed rounded-full flex items-center justify-center font-headline-md text-headline-md text-electric-blue mb-4 shadow-inner">01</div>
              <h4 class="font-label-bold text-label-bold text-on-surface mb-2 text-lg">Kirim</h4>
              <p class="font-body-md text-body-md text-on-surface-variant text-sm">Kirim tugas, screenshot error, atau brief lewat WhatsApp.</p>
            </div>

            <div class="flex-1 bg-surface-white rounded-2xl p-6 shadow-sm border border-border-subtle relative z-10 flex flex-col items-center text-center hover:-translate-y-1 transition-transform duration-300">
              <div class="w-12 h-12 bg-primary-fixed rounded-full flex items-center justify-center font-headline-md text-headline-md text-electric-blue mb-4 shadow-inner">02</div>
              <h4 class="font-label-bold text-label-bold text-on-surface mb-2 text-lg">Dicek</h4>
              <p class="font-body-md text-body-md text-on-surface-variant text-sm">Kami cek tingkat kesulitan dan estimasi waktu pengerjaannya.</p>
            </div>

            <div class="flex-1 bg-surface-white rounded-2xl p-6 shadow-sm border border-border-subtle relative z-10 flex flex-col items-center text-center hover:-translate-y-1 transition-transform duration-300">
              <div class="w-12 h-12 bg-primary-fixed rounded-full flex items-center justify-center font-headline-md text-headline-md text-electric-blue mb-4 shadow-inner">03</div>
              <h4 class="font-label-bold text-label-bold text-on-surface mb-2 text-lg">Nego</h4>
              <p class="font-body-md text-body-md text-on-surface-variant text-sm">Diskusikan harga yang masuk akal dan sesuai budget mahasiswa.</p>
            </div>

            <div class="flex-1 bg-surface-white rounded-2xl p-6 shadow-sm border border-border-subtle relative z-10 flex flex-col items-center text-center hover:-translate-y-1 transition-transform duration-300">
              <div class="w-12 h-12 bg-primary-fixed rounded-full flex items-center justify-center font-headline-md text-headline-md text-electric-blue mb-4 shadow-inner">04</div>
              <h4 class="font-label-bold text-label-bold text-on-surface mb-2 text-lg">Deal</h4>
              <p class="font-body-md text-body-md text-on-surface-variant text-sm">Setelah deal dan DP, kami langsung mulai mengerjakan.</p>
            </div>

            <div class="flex-1 bg-surface-white rounded-2xl p-6 shadow-sm border border-electric-blue/30 relative z-10 flex flex-col items-center text-center hover:-translate-y-1 transition-transform duration-300 ring-2 ring-electric-blue/10">
              <div class="w-12 h-12 bg-electric-blue rounded-full flex items-center justify-center font-headline-md text-headline-md text-surface-white mb-4 shadow-md">
                <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">task_alt</span>
              </div>
              <h4 class="font-label-bold text-label-bold text-electric-blue mb-2 text-lg">Beres</h4>
              <p class="font-body-md text-body-md text-on-surface-variant text-sm">Project selesai, kita review bareng, lalu siap dikumpulkan.</p>
            </div>
          </div>
        </div>
      </section>

      <!-- Engineer Profile Section -->
      <section class="px-gutter max-w-container-max-width mx-auto w-full" id="about">
        <div class="bg-surface-white border border-border-subtle rounded-3xl p-8 md:p-12 shadow-sm flex flex-col md:flex-row items-center gap-10">
          <div class="relative">
            <img
              class="w-48 h-48 md:w-64 md:h-64 rounded-full object-cover border-4 border-surface-white shadow-lg"
              alt="Engineer JokiTugasIT"
              width="256"
              height="256"
              loading="lazy"
              decoding="async"
              src="https://lh3.googleusercontent.com/aida-public/AB6AXuDR8RkLI8_HBU4ssWVtUwGtrTtUwVrnu6ATXMjApcpX6tEXsgv63arNTK4UHyIL2rTfCOXc76-S8CzZhHa5gCrLqvjxnI-9hL2U9mmviC9OvFsA2hXb-tz4Lxbaq5C-JtEZ9kkf7BXFfvb-FNyzFmOyadu8EI_0_jQGMIw7PtGeyQbBYrOX7rpENsCCIKZc8b_piKWRueDw4IfOlhyPT60Y7Hl5r5zi_MkHdnKzdxEsibTRQOOCsLuN"
            />
            <div class="absolute bottom-4 right-4 bg-surface-white px-3 py-1.5 rounded-full border border-border-subtle shadow-md flex items-center gap-2">
              <div class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse-slow"></div>
              <span class="font-label-sm text-label-sm text-on-surface font-bold">Online</span>
            </div>
          </div>
          <div class="flex-1 text-center md:text-left">
            <h2 class="font-headline-lg text-headline-lg text-on-surface mb-2">
              Bukan agensi yang bikin sungkan,<br />tapi <span class="text-electric-blue">teman ngoding</span>-mu.
            </h2>
            <p class="font-body-md text-body-md text-on-surface-variant mb-6 max-w-xl">
              Kami paham rasanya dikejar deadline, error muncul tengah malam, dan tugas belum kelar. Kami bantu dengan standar profesional, tapi komunikasinya tetap santai seperti teman sendiri.
            </p>
            <div class="flex flex-wrap justify-center md:justify-start gap-4 mb-8">
              <div class="bg-surface-container-low px-4 py-3 rounded-xl border border-border-subtle text-center min-w-[120px]">
                <span class="block font-headline-md text-headline-md text-electric-blue mb-1">5+</span>
                <span class="font-label-sm text-label-sm text-secondary">Tahun Pengalaman</span>
              </div>
              <div class="bg-surface-container-low px-4 py-3 rounded-xl border border-border-subtle text-center min-w-[120px]">
                <span class="block font-headline-md text-headline-md text-electric-blue mb-1">24/7</span>
                <span class="font-label-sm text-label-sm text-secondary">Support Tanya Jawab</span>
              </div>
            </div>
            <a
              :href="waLink('6285166337257', WA_TEXT)"
              target="_blank"
              rel="noopener"
              class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-8 py-3.5 rounded-xl hover:bg-primary-fixed/20 transition-colors shadow-sm h-[48px] inline-flex items-center gap-2"
            >
              <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">forum</span>
              Ngobrol dengan Kami
            </a>
          </div>
        </div>
      </section>

      <!-- Partner Referral CTA Section -->
      <section class="py-16 md:py-20 px-gutter">
        <div class="max-w-container-max-width mx-auto">
          <div class="relative overflow-hidden bg-gradient-to-r from-electric-blue via-primary to-tertiary rounded-3xl p-8 md:p-12 text-white">
            <div class="absolute inset-0 opacity-10" style="background-image: radial-gradient(circle at 10% 50%, #fff 1px, transparent 1px), radial-gradient(circle at 90% 20%, #fff 1px, transparent 1px); background-size: 30px 30px;"></div>
            <div class="relative flex flex-col md:flex-row items-center justify-between gap-8">
              <div class="flex-1">
                <div class="inline-flex items-center gap-1.5 bg-white/15 border border-white/25 rounded-full px-3 py-1 text-[12px] font-bold mb-4">
                  <span class="material-symbols-outlined text-[14px]" style="font-variation-settings: 'FILL' 1">monetization_on</span>
                  Program Partner Referral
                </div>
                <h2 class="text-2xl md:text-3xl font-bold mb-3">Punya Teman yang Mentok Ngoding?</h2>
                <p class="text-white/80 mb-0 max-w-xl">
                  Rekomendasikan ke engineer jokitugasit.my.id dan kamu dapat
                  <span class="text-tertiary-fixed font-bold">komisi 10%</span> per transaksi yang berhasil.
                  Tanpa modal, tanpa keahlian ngoding.
                </p>
              </div>
              <div class="flex flex-col sm:flex-row md:flex-col gap-3 flex-shrink-0">
                <RouterLink to="/partner"
                  class="inline-flex items-center justify-center gap-2 bg-white text-electric-blue font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:shadow-lg hover:-translate-y-0.5 transition-all">
                  <span class="material-symbols-outlined text-[20px]" style="font-variation-settings: 'FILL' 1">how_to_reg</span>
                  Daftar Jadi Partner
                </RouterLink>
                <div class="text-center text-white/60 text-xs pt-1">Gratis · Komisi cair 24 jam</div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </main>

    <!-- Floating action (mobile) -->
    <RouterLink
      to="/request"
      class="fixed bottom-[80px] right-4 z-40 md:hidden bg-electric-blue text-surface-white w-14 h-14 rounded-full flex items-center justify-center shadow-lg hover:bg-primary transition-colors active:scale-90"
    >
      <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">send</span>
    </RouterLink>

    <FooterBar />
    <BottomNavBar />
  </div>
</template>