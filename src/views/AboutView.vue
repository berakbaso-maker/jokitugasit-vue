<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo jokitugasit.my.id, saya mau konsultasi langsung dengan engineer.'

const specializations = [
  { icon: 'dns', title: 'Backend', desc: 'Robust APIs, database architecture, dan server-side logic yang scalable.' },
  { icon: 'web', title: 'Frontend', desc: 'Responsive, pixel-perfect user interfaces dengan framework modern.' },
  { icon: 'smartphone', title: 'Mobile', desc: 'Cross-platform app development untuk iOS dan Android.' },
  { icon: 'cloud_sync', title: 'DevOps', desc: 'Deployment pipelines, containerization, dan cloud infrastructure.' },
]

const techStacks = ['Laravel', 'Flutter', 'Python', 'Node.js', 'React', 'Vue.js', 'MySQL', 'PostgreSQL', 'Docker', 'AWS', 'Git', 'Supabase']
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Hero -->
      <section class="text-center max-w-3xl mx-auto mb-16">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-1.5 shadow-sm mb-4">
          <span class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse-slow"></span>
          <span class="font-label-sm text-label-sm text-secondary">Engineer Siap Bantu</span>
        </div>
        <h1 class="font-display-hero-mobile md:font-display-hero text-display-hero-mobile md:text-display-hero font-bold text-on-surface mb-5">
          Engineer yang Ngerti<br /><span class="text-electric-blue">Kesulitan Mahasiswa.</span>
        </h1>
        <p class="font-body-lg text-body-lg text-on-surface-variant max-w-2xl mx-auto mb-8">
          Bukan sekadar nulis kode — kami bantu kamu paham. Anggap kami teman ngoding yang jembatani kesenjangan antara teknikal yang rumit dan tugas kamu yang harus beres, tepat waktu.
        </p>
        <div class="flex flex-wrap justify-center gap-3 mb-8">
          <div class="bg-surface-white border border-border-subtle rounded-xl px-5 py-3 shadow-sm">
            <div class="flex items-center gap-2">
              <span class="material-symbols-outlined text-electric-blue">verified</span>
              <span class="font-label-bold text-label-bold text-on-surface">5+ Tahun Pengalaman</span>
            </div>
          </div>
          <div class="bg-surface-white border border-border-subtle rounded-xl px-5 py-3 shadow-sm">
            <div class="flex items-center gap-2">
              <span class="material-symbols-outlined text-electric-blue">school</span>
              <span class="font-label-bold text-label-bold text-on-surface">Alumni Ilmu Komputer</span>
            </div>
          </div>
        </div>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-accent-fill text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl shadow-md hover:bg-accent-fill transition-colors flex items-center justify-center gap-2">
            <span class="material-symbols-outlined">send</span>
            Kirim Project
          </RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-primary-fixed/20 transition-colors flex items-center justify-center gap-2">
            <span class="material-symbols-outlined">forum</span>
            Konsultasi Langsung
          </a>
        </div>
      </section>

      <!-- Core Specializations -->
      <section class="mb-16">
        <h2 class="font-headline-lg text-headline-lg font-bold text-center text-on-surface mb-10">Spesialisasi Utama</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          <div v-for="s in specializations" :key="s.title" class="bg-surface-white rounded-2xl p-6 border border-border-subtle shadow-sm hover:shadow-md hover:border-electric-blue transition-all">
            <span class="w-12 h-12 rounded-xl bg-primary-fixed/40 text-electric-blue flex items-center justify-center mb-4">
              <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">{{ s.icon }}</span>
            </span>
            <h3 class="font-headline-md text-headline-md font-bold text-on-surface mb-2">{{ s.title }}</h3>
            <p class="text-sm text-secondary leading-6">{{ s.desc }}</p>
          </div>
        </div>
      </section>

      <!-- Tech Stack -->
      <section class="bg-surface-white rounded-2xl border border-border-subtle shadow-sm p-6 md:p-8 mb-16">
        <h2 class="font-headline-lg text-headline-lg font-bold text-on-surface mb-6 text-center">Tech Stack</h2>
        <div class="flex flex-wrap justify-center gap-2.5">
          <span v-for="t in techStacks" :key="t" class="bg-surface-container-low border border-border-subtle px-4 py-2 rounded-full font-label-sm text-label-sm text-on-surface">{{ t }}</span>
        </div>
      </section>

      <!-- Visi & Misi -->
      <section class="bg-accent-fill rounded-2xl p-8 md:p-12 text-center text-white relative overflow-hidden mb-0">
        <div class="absolute inset-0 bg-primary opacity-20 -z-10"></div>
        <span class="material-symbols-outlined text-4xl mb-3" style="font-variation-settings: 'FILL' 1">psychology</span>
        <h2 class="font-headline-lg text-headline-lg font-bold mb-3">Visi & Misi</h2>
        <p class="font-headline-md text-headline-md font-bold mb-4">"Bantu mahasiswa lulus dengan kode berkualitas."</p>
        <p class="text-body-md text-body-md opacity-90 max-w-xl mx-auto">Kami bantu demystify software development untuk mahasiswa. Memberikan kode berkualitas tinggi dan penjelasan yang jelas, supaya kamu bisa mempertanggungjawabkan project-mu dengan percaya diri.</p>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
