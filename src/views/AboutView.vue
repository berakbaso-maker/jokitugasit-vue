<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo JokiTugasIT.id, saya mau kenalan sama tim engineer-nya.'

const values = [
  { icon: 'school', title: 'Paham Mahasiswa', desc: 'Kami pernah ngerasain dikejar deadline, error tengah malam, dan tugas belum kelar.' },
  { icon: 'verified', title: 'Hasil Profesional', desc: 'Standar pengerjaan tetap industri, biar nilai dan kualitas project-mu aman.' },
  { icon: 'chat', title: 'Komunikasi Santai', desc: 'Ngobrol kaya temen sendiri, nggak pake istilah ribet. Dijelasin sampai paham.' },
  { icon: 'lock', title: 'Privasi Terjaga', desc: 'Data dan project kamu dirahasiakan. Nggak akan disebar ke mana-mana.' },
]
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Header -->
      <section class="text-center max-w-2xl mx-auto mb-14">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5">
          <span class="material-symbols-outlined text-electric-blue text-[18px]">group</span>
          <span class="font-label-sm text-label-sm text-secondary">Tentang Kami</span>
        </div>
        <h1 class="font-headline-lg text-headline-lg md:text-display-hero-mobile font-bold text-on-surface mb-3">Bukan agensi yang bikin sungkan, tapi teman ngoding-mu.</h1>
        <p class="text-body-lg font-body-lg text-on-surface-variant">Kami paham rasanya dikejar deadline, error muncul tengah malam, dan tugas belum kelar. Kami bantu dengan standar profesional, tapi komunikasinya tetap santai seperti teman sendiri.</p>
      </section>

      <!-- Profile card -->
      <section class="bg-surface-white border border-border-subtle rounded-3xl p-8 md:p-12 shadow-sm mb-16">
        <div class="flex flex-col md:flex-row items-center gap-10">
          <div class="relative shrink-0">
            <div class="w-40 h-40 md:w-48 md:h-48 rounded-full bg-primary-fixed/40 flex items-center justify-center text-electric-blue">
              <span class="material-symbols-outlined text-6xl" style="font-variation-settings: 'FILL' 1">terminal</span>
            </div>
            <div class="absolute bottom-2 right-2 bg-surface-white px-3 py-1.5 rounded-full border border-border-subtle shadow-md flex items-center gap-2">
              <div class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse-slow"></div>
              <span class="font-label-sm text-label-sm text-on-surface font-bold">Online</span>
            </div>
          </div>
          <div class="flex-1 text-center md:text-left">
            <h2 class="font-headline-lg text-headline-lg font-bold mb-3">JokiTugasIT.id</h2>
            <p class="font-body-md text-body-md text-on-surface-variant mb-6 leading-7">Layanan bantu tugas IT yang digerakkan oleh engineer profesional. Fokus kami satu: bikin project kuliah dan tugas IT kamu selesai dengan kualitas bagus, harga ramah, dan proses yang jujur dari awal sampai akhir.</p>
            <div class="flex flex-wrap justify-center md:justify-start gap-4">
              <div class="bg-surface-container-low px-4 py-3 rounded-xl border border-border-subtle text-center min-w-[120px]">
                <span class="block font-headline-md text-headline-md text-electric-blue mb-1">5+</span>
                <span class="font-label-sm text-label-sm text-secondary">Tahun Pengalaman</span>
              </div>
              <div class="bg-surface-container-low px-4 py-3 rounded-xl border border-border-subtle text-center min-w-[120px]">
                <span class="block font-headline-md text-headline-md text-electric-blue mb-1">1k+</span>
                <span class="font-label-sm text-label-sm text-secondary">Project Beres</span>
              </div>
              <div class="bg-surface-container-low px-4 py-3 rounded-xl border border-border-subtle text-center min-w-[120px]">
                <span class="block font-headline-md text-headline-md text-electric-blue mb-1">24/7</span>
                <span class="font-label-sm text-label-sm text-secondary">Support Tanya Jawab</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Nilai -->
      <section class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5 mb-16">
        <div v-for="v in values" :key="v.title" class="bg-surface-white rounded-xl p-5 border border-border-subtle shadow-sm">
          <span class="w-11 h-11 rounded-lg bg-primary-fixed/40 text-electric-blue flex items-center justify-center mb-3">
            <span class="material-symbols-outlined">{{ v.icon }}</span>
          </span>
          <h3 class="font-label-bold text-label-bold text-on-surface mb-1">{{ v.title }}</h3>
          <p class="text-sm text-secondary leading-6">{{ v.desc }}</p>
        </div>
      </section>

      <!-- CTA -->
      <section class="text-center bg-surface-container rounded-2xl p-10">
        <h2 class="font-headline-lg text-headline-lg font-bold mb-3">Mau ngobrol langsung?</h2>
        <p class="text-body-md text-body-md text-secondary mb-7">Ceritain project-mu, kami bantu cari solusinya bareng-bareng.</p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-electric-blue text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-primary transition-colors shadow-md">Konsultasi Gratis</RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-primary-fixed/20 transition-colors">Ngobrol di WhatsApp</a>
        </div>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
