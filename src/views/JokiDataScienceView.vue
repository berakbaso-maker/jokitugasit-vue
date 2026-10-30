<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo jokitugasit.my.id, saya butuh bantuan data science / AI.'

const problems = [
  { icon: 'analytics', title: 'Analisis Data Rumit', desc: 'Data kotor, format beda-beda, atau bingung mulai analisis dari mana.', color: 'bg-error-container text-error' },
  { icon: 'model_training', title: 'Model ML Gagal', desc: 'Akurasi rendah, overfitting, atau model error pas dipakai prediksi.', color: 'bg-primary-fixed/40 text-electric-blue' },
  { icon: 'cloud_download', title: 'Scraping Bermasalah', desc: 'Anti-scraping, struktur HTML berubah, atau data yang diambil nggak lengkap.', color: 'bg-tertiary-fixed/40 text-tertiary' },
]

const stacks = ['Python', 'Pandas', 'Scikit-learn', 'TensorFlow', 'Jupyter']
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <section class="text-center max-w-3xl mx-auto mb-16">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5">
          <div class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse-slow"></div>
          <span class="font-label-sm text-label-sm text-secondary">Bantuan Data Science & AI</span>
        </div>
        <h1 class="font-display-hero-mobile text-display-hero-mobile md:font-display-hero md:text-display-hero font-bold text-on-surface mb-5">
          Data Numpuk?<br />
          <span class="text-electric-blue">AI-nya Gak Jalan?</span>
        </h1>
        <p class="font-body-lg text-body-lg text-on-surface-variant max-w-2xl mx-auto mb-9">Analisis data, machine learning models, scraping, dan implementasi algoritma AI untuk tugas kuliah atau riset. Hasil rapi, laporan siap.</p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-accent-fill text-white font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-accent-fill transition-colors shadow-lg flex items-center justify-center gap-2">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">rocket_launch</span>
            Cek Project Gratis
          </RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-primary-fixed/20 transition-colors flex items-center justify-center gap-2">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">chat</span>
            Konsultasi Gratis
          </a>
        </div>
        <div class="flex flex-wrap justify-center gap-2 mt-7">
          <span v-for="st in stacks" :key="st" class="bg-surface-white border border-border-subtle px-3 py-1.5 rounded-full font-label-sm text-label-sm text-secondary">{{ st }}</span>
        </div>
      </section>

      <section class="mb-16">
        <h2 class="font-headline-lg text-headline-lg font-bold text-center text-on-surface mb-10">Masalah yang Sering Kami Tangani</h2>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-5">
          <div v-for="p in problems" :key="p.title" class="bg-surface-white rounded-xl p-6 border border-border-subtle shadow-sm hover:shadow-md hover:border-electric-blue transition-all">
            <span class="w-12 h-12 rounded-xl flex items-center justify-center mb-4" :class="p.color">
              <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">{{ p.icon }}</span>
            </span>
            <h3 class="font-headline-md text-headline-md font-bold text-on-surface mb-2">{{ p.title }}</h3>
            <p class="text-sm text-secondary leading-6">{{ p.desc }}</p>
          </div>
        </div>
      </section>

      <section class="bg-accent-fill rounded-2xl p-8 md:p-12 text-center text-white relative overflow-hidden">
        <div class="absolute inset-0 bg-primary opacity-20 -z-10"></div>
        <h2 class="font-headline-lg text-headline-lg font-bold mb-3">Data & AI Beres Total</h2>
        <p class="text-body-md text-on-primary opacity-90 max-w-lg mx-auto mb-7">Ceritakan masalahmu, kami cek dulu gratis dan kasih estimasi.</p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-white text-accent-fill font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-surface-container-lowest transition-colors shadow-md">Kirim Sekarang</RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="border-2 border-white text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-white/10 transition-colors">Chat WhatsApp</a>
        </div>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
