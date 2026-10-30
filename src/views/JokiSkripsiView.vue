<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo jokitugasit.my.id, saya butuh bantuan skripsi / tugas akhir IT.'

const problems = [
  { icon: 'sos', title: 'Code Hasil AI Berantakan', desc: 'Code dari ChatGPT atau Cursor error, logic muter-muter, dan susah dipahami dosen.', color: 'bg-error-container text-error' },
  { icon: 'link_off', title: 'Integrasi API & DB Gagal', desc: 'Frontend dan Backend nggak nyambung, data nggak muncul, atau relasi database kacau.', color: 'bg-primary-fixed/40 text-electric-blue' },
  { icon: 'pending_actions', title: 'Fitur Belum Selesai', desc: 'Deadline mepet tapi masih banyak fitur krusial yang belum jalan dan bug menumpuk.', color: 'bg-tertiary-fixed/40 text-tertiary' },
  { icon: 'rocket_launch', title: 'Persiapan Demo & Deploy', desc: 'Aplikasi jalan di localhost tapi bingung cara hosting ke VPS, Docker, atau Vercel.', color: 'bg-success-green/10 text-success-green' },
]

const packages = [
  { name: 'Minor Fix', popular: false,
    desc: 'Untuk debugging dan optimasi ringan.',
    features: ['Perbaikan 1 bug / error', 'Optimasi kecil', 'Revisi sekali', 'Cepat selesai'] },
  { name: 'Feature Add-on', popular: true,
    desc: 'Nambah modul atau integrasi baru.',
    features: ['1 fitur/modul baru', 'Integrasi API/DB', 'Testing & demo', 'Revisi 2x'] },
  { name: 'Full Project Support', popular: false,
    desc: 'Bantuan teknis menyeluruh (A-Z).',
    features: ['Review seluruh codebase', 'Fix semua bug', 'Persiapan demo & deploy', 'Pendampingan sampai sidang'] },
]
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Hero -->
      <section class="text-center max-w-3xl mx-auto mb-16">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5">
          <div class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse-slow"></div>
          <span class="font-label-sm text-label-sm text-secondary">Bantuan Skripsi & Final Project</span>
        </div>
        <h1 class="font-display-hero-mobile text-display-hero-mobile md:font-display-hero md:text-display-hero font-bold text-on-surface mb-5">
          Skripsi IT Stuck?<br />
          <span class="text-electric-blue">Selesaikan Tanpa Drama.</span>
        </h1>
        <p class="font-body-lg text-body-lg text-on-surface-variant max-w-2xl mx-auto mb-9">
          Bantuan teknis untuk Skripsi, Tugas Akhir, dan Capstone Project. Mulai dari perbaikan bug, integrasi API & database, sampai persiapan demo dan deploy.
        </p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-accent-fill text-white font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-accent-fill transition-colors shadow-lg flex items-center justify-center gap-2">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">rocket_launch</span>
            Cek Project Gratis
          </RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-primary-fixed/20 transition-colors flex items-center justify-center gap-2">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">chat</span>
            Konsultasi Skripsi Gratis
          </a>
        </div>
      </section>

      <!-- Problems -->
      <section class="mb-16">
        <h2 class="font-headline-lg text-headline-lg font-bold text-center text-on-surface mb-10">Masalah yang Sering Kami Tangani</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          <div v-for="p in problems" :key="p.title" class="bg-surface-white rounded-xl p-6 border border-border-subtle shadow-sm hover:shadow-md hover:border-electric-blue transition-all">
            <span class="w-12 h-12 rounded-xl flex items-center justify-center mb-4" :class="p.color">
              <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">{{ p.icon }}</span>
            </span>
            <h3 class="font-headline-md text-headline-md font-bold text-on-surface mb-2">{{ p.title }}</h3>
            <p class="text-sm text-secondary leading-6">{{ p.desc }}</p>
          </div>
        </div>
      </section>

      <!-- Packages -->
      <section class="mb-16">
        <h2 class="font-headline-lg text-headline-lg font-bold text-center text-on-surface mb-10">Pilih Paket Sesuai Kebutuhan</h2>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div v-for="pkg in packages" :key="pkg.name"
            class="relative bg-surface-white rounded-2xl p-7 border shadow-sm flex flex-col"
            :class="pkg.popular ? 'border-electric-blue ring-2 ring-electric-blue/20' : 'border-border-subtle'">
            <span v-if="pkg.popular" class="absolute -top-3 left-1/2 -translate-x-1/2 bg-accent-fill text-white text-[10px] font-bold uppercase tracking-wider px-3 py-1 rounded-full">Paling Laku</span>
            <h3 class="font-headline-md text-headline-md font-bold text-on-surface mb-1">{{ pkg.name }}</h3>
            <p class="text-sm text-secondary mb-4">{{ pkg.desc }}</p>
            <div class="mb-5 rounded-xl bg-primary-fixed/30 border border-primary-fixed px-4 py-3">
              <div class="flex items-center gap-2 text-electric-blue mb-1">
                <span class="material-symbols-outlined text-[20px]">handshake</span>
                <span class="font-label-bold text-label-bold">Konsultasi sesuai kebutuhan</span>
              </div>
              <p class="text-xs text-on-surface-variant">Ceritakan detailnya, kami bantu cari solusi yang paling pas.</p>
            </div>
            <ul class="space-y-2.5 mb-7 flex-grow">
              <li v-for="f in pkg.features" :key="f" class="flex items-start gap-2 text-sm text-on-surface-variant">
                <span class="material-symbols-outlined text-[16px] text-success-green shrink-0">check_circle</span>
                {{ f }}
              </li>
            </ul>
            <a :href="waLink('6285166337257', `Halo, saya mau konsultasi paket ${pkg.name} untuk skripsi saya.`)" target="_blank" rel="noopener"
              class="w-full text-center py-3 rounded-xl font-label-bold text-label-bold transition-colors inline-flex items-center justify-center gap-2"
              :class="pkg.popular ? 'bg-accent-fill text-white hover:bg-accent-fill' : 'border-2 border-electric-blue text-electric-blue hover:bg-primary-fixed/20'">
              <span class="material-symbols-outlined text-[18px]">chat</span>
              Konsultasi ke Engineer
            </a>
          </div>
        </div>
      </section>

      <!-- CTA Deadline -->
      <section class="bg-accent-fill rounded-2xl p-8 md:p-12 text-center text-white relative overflow-hidden">
        <div class="absolute inset-0 bg-primary opacity-20 -z-10"></div>
        <h2 class="font-headline-lg text-headline-lg font-bold mb-3">Punya Deadline Dekat?</h2>
        <p class="text-body-md text-on-primary opacity-90 max-w-lg mx-auto mb-7">Jangan nunggu mepet. Ceritakan kondisi skripsi-mu sekarang, kami bantu prioritasin mana yang harus beres duluan.</p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-white text-accent-fill font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-surface-container-lowest transition-colors shadow-md">Lihat Paket Layanan</RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="border-2 border-white text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-white/10 transition-colors">Konsultasi Gratis</a>
        </div>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
