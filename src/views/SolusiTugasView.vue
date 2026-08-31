<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo JokiTugasIT.id, saya cari solusi tugas IT saya.'

const categories = [
  { icon: 'web', title: 'Web Development', link: '/joki-project-web', color: 'bg-primary-fixed/40 text-electric-blue',
    desc: 'Pembuatan website company profile, sistem informasi akademik, toko online, hingga custom CMS.' },
  { icon: 'smartphone', title: 'Mobile Apps', link: '/joki-tugas-mobile-app', color: 'bg-primary-fixed/40 text-electric-blue',
    desc: 'Aplikasi Android dan iOS native maupun cross-platform untuk tugas akhir atau project kuliah.' },
  { icon: 'database', title: 'Database & API', link: '/layanan', color: 'bg-tertiary-fixed/40 text-tertiary',
    desc: 'Desain skema database, optimalisasi query, dan pembuatan RESTful API / GraphQL.' },
  { icon: 'monitoring', title: 'Data Science & AI', link: '/layanan', color: 'bg-error-container text-urgency-red',
    desc: 'Analisis data, machine learning models, scraping, dan implementasi algoritma AI.' },
  { icon: 'school', title: 'Tugas Umum & Algoritma', link: '/joki-tugas-kuliah-it', color: 'bg-primary-fixed/40 text-electric-blue',
    desc: 'Dasar pemrograman, struktur data, logika informatika, sampai tugas kuliah pemrograman.' },
  { icon: 'palette', title: 'UI/UX Design', link: '/layanan', color: 'bg-success-green/10 text-success-green',
    desc: 'Desain tampilan aplikasi dan website yang modern, rapi, dan sesuai kebutuhan.' },
  { icon: 'menu_book', title: 'Skripsi & TA', link: '/joki-skripsi-it', color: 'bg-tertiary-fixed/40 text-tertiary',
    desc: 'Pendampingan teknis skripsi: fix bug, integrasi, demo, sampai deploy.' },
]
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Hero -->
      <section class="text-center max-w-3xl mx-auto mb-14">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5">
          <span class="material-symbols-outlined text-electric-blue text-[18px]">hub</span>
          <span class="font-label-sm text-label-sm text-secondary">Direktori Solusi Tugas IT</span>
        </div>
        <h1 class="font-display-hero-mobile text-display-hero-mobile md:font-display-hero md:text-display-hero font-bold text-on-surface mb-4">
          Tugas IT Beres,<br />
          <span class="text-electric-blue">Kamu Tenang.</span>
        </h1>
        <p class="font-body-lg text-body-lg text-on-surface-variant max-w-2xl mx-auto mb-8">
          Eksplorasi direktori layanan lengkap kami. Dari perbaikan bug kecil hingga aplikasi full-stack, semua dibantu sampai beres.
        </p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-electric-blue text-white font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-primary transition-colors shadow-lg flex items-center justify-center gap-2">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">rocket_launch</span>
            Cek Project Gratis
          </RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-primary-fixed/20 transition-colors flex items-center justify-center gap-2">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">chat</span>
            Konsultasi Gratis
          </a>
        </div>
      </section>

      <!-- Directory Grid -->
      <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-5 mb-16">
        <RouterLink v-for="c in categories" :key="c.title" :to="c.link"
          class="group bg-surface-white rounded-xl p-6 border border-border-subtle shadow-sm hover:shadow-md hover:border-electric-blue transition-all">
          <span class="w-12 h-12 rounded-xl flex items-center justify-center mb-4" :class="c.color">
            <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">{{ c.icon }}</span>
          </span>
          <h2 class="font-headline-md text-headline-md font-bold text-on-surface mb-2">{{ c.title }}</h2>
          <p class="text-sm text-secondary leading-6 mb-4">{{ c.desc }}</p>
          <span class="inline-flex items-center gap-1 text-electric-blue font-label-bold text-label-bold group-hover:gap-2 transition-all">Lihat Layanan <span class="material-symbols-outlined text-[18px]">arrow_forward</span></span>
        </RouterLink>
      </section>

      <!-- CTA -->
      <section class="bg-electric-blue rounded-2xl p-8 md:p-12 text-center text-white relative overflow-hidden">
        <div class="absolute inset-0 bg-primary opacity-20 -z-10"></div>
        <h2 class="font-headline-lg text-headline-lg font-bold mb-3">Masih Bingung Pilih Layanan?</h2>
        <p class="text-body-md text-body-md text-on-primary-container opacity-90 max-w-lg mx-auto mb-7">Ceritakan saja masalahmu, kami bantu tentukan solusi yang paling pas.</p>
        <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="inline-flex items-center gap-2 bg-white text-electric-blue font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-surface-container-lowest transition-colors shadow-md">
          <span class="material-symbols-outlined">chat</span>
          Konsultasi Gratis
        </a>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
