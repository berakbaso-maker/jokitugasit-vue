<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/tautan'

const WA_TEXT = 'Halo jokitugasit.my.id, saya butuh bantuan tugas kuliah IT (dasar pemrograman).'

const painPoints = [
  { icon: 'error', title: 'Tugas Numpuk', desc: 'Beberapa tugas datang bersamaan dan semua deadline-nya mepet.' },
  { icon: 'schedule', title: 'Deadline Mepet', desc: 'Besok pagi dikumpul, hari ini masih belum paham materinya.' },
  { icon: 'code_off', title: 'Nggak Paham Kode', desc: 'Materi dosen cepat banget, nyoba sendiri tetap error.' },
]

const courses = [
  { icon: 'terminal', title: 'Dasar Pemrograman', desc: 'Tugas basic C++, Java, dan Python. Bikin program console, kalkulator, atau mini project.', tags: ['C++', 'Java', 'Python'] },
  { icon: 'account_tree', title: 'Algoritma & Struktur Data', desc: 'Sorting, searching, linked list, tree, graph. Implementasi algoritma dari teori ke kode.', tags: ['Sorting', 'Linked List', 'Tree', 'Graph'] },
  { icon: 'psychology', title: 'Logika Informatika', desc: 'Gerbang logika, tabel kebenaran, aljabar boolean, dan penyelesaian masalah logis lainnya.', tags: ['Gerbang Logika', 'Boolean', 'Tabel Kebenaran'] },
  { icon: 'database', title: 'Basis Data', desc: 'SQL, normalisasi, ERD, sampai query kompleks untuk tugas basis data.', tags: ['SQL', 'ERD', 'MySQL'] },
]
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main id="konten-utama" tabindex="-1" class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Hero -->
      <section class="text-center max-w-2xl mx-auto mb-14">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5">
          <div class="w-2.5 h-2.5 rounded-full bg-success-green animate-pulse-slow"></div>
          <span class="font-label-sm text-label-sm text-secondary">Engineer siap bantu sekarang</span>
        </div>
        <h1 class="font-display-hero-mobile text-display-hero-mobile md:font-display-hero md:text-display-hero font-bold text-on-surface mb-4">
          Tugas Numpuk?<br />
          <span class="text-electric-blue">Deadline Mepet?</span>
        </h1>
        <p class="font-body-lg text-body-lg text-on-surface-variant max-w-xl mx-auto mb-8">
          Jasa joki tugas kuliah IT umum terpercaya. Mulai dari dasar C++, Java, Python, hingga algoritma kompleks. Pengerjaan cepat, harga ramah mahasiswa.
        </p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-accent-fill text-white font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-accent-fill transition-colors shadow-lg flex items-center justify-center gap-2">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">rocket_launch</span>
            Cek Tugas Gratis
          </RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-8 py-4 rounded-xl hover:bg-primary-fixed/20 transition-colors flex items-center justify-center gap-2">
            <span class="material-symbols-outlined" style="font-variation-settings: 'FILL' 1">chat</span>
            Konsultasi Gratis
          </a>
        </div>
      </section>

      <!-- Pain points -->
      <section class="grid grid-cols-1 sm:grid-cols-3 gap-5 mb-14">
        <div v-for="p in painPoints" :key="p.title" class="bg-surface-white rounded-xl p-5 border border-border-subtle shadow-sm">
          <span class="w-11 h-11 rounded-lg bg-error-container text-error flex items-center justify-center mb-3">
            <span class="material-symbols-outlined">{{ p.icon }}</span>
          </span>
          <h2 class="font-label-bold text-label-bold text-on-surface mb-1">{{ p.title }}</h2>
          <p class="text-sm text-secondary leading-6">{{ p.desc }}</p>
        </div>
      </section>

      <!-- Courses -->
      <section class="mb-14">
        <div class="text-center mb-10">
          <h2 class="font-headline-lg text-headline-lg font-bold text-on-surface mb-3">Layanan Joki Tugas IT</h2>
          <p class="text-body-md text-body-md text-secondary">Solusi cepat untuk berbagai mata kuliah pemrograman dasar.</p>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div v-for="c in courses" :key="c.title" class="group bg-surface-white border border-border-subtle rounded-2xl p-6 shadow-sm hover:shadow-md hover:border-electric-blue transition-all">
            <span class="w-12 h-12 rounded-xl bg-primary-fixed/40 text-electric-blue flex items-center justify-center mb-4">
              <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">{{ c.icon }}</span>
            </span>
            <h3 class="font-headline-md text-headline-md font-bold text-on-surface mb-2">{{ c.title }}</h3>
            <p class="font-body-md text-body-md text-on-surface-variant mb-4">{{ c.desc }}</p>
            <div class="flex flex-wrap gap-2">
              <span v-for="t in c.tags" :key="t" class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">{{ t }}</span>
            </div>
          </div>
        </div>
      </section>

      <!-- CTA -->
      <section class="bg-accent-fill rounded-2xl p-8 md:p-12 text-center text-white relative overflow-hidden">
        <div class="absolute inset-0 bg-primary opacity-20 -z-10"></div>
        <h2 class="font-headline-lg text-headline-lg font-bold mb-3">Tugas IT Beres, Kamu Tenang.</h2>
        <p class="text-body-md text-on-primary opacity-90 max-w-lg mx-auto mb-7">Kirim tugasmu sekarang, kami kerjakan dengan standar profesional dan harga ramah mahasiswa.</p>
        <RouterLink to="/request" class="inline-flex items-center gap-2 bg-white text-accent-fill font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-surface-container-lowest transition-colors shadow-md">
          <span class="material-symbols-outlined">send</span>
          Konsultasi Gratis Sekarang
        </RouterLink>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
