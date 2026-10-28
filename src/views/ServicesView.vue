<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/api'

const WA_TEXT = 'Halo jokitugasit.my.id, saya butuh bantuan untuk project IT saya.'

const services = [
  {
    icon: 'language', title: 'Bikin Website', color: 'bg-primary-fixed/50 text-electric-blue', link: '/joki-project-web',
    desc: 'Landing page, dashboard admin, sistem informasi, toko online, sampai slicing Figma ke HTML/React. Beres rapi dan siap pakai.',
    tags: ['React', 'Next.js', 'PHP', 'Laravel', 'HTML/CSS'],
  },
  {
    icon: 'smartphone', title: 'Bikin Aplikasi Mobile', color: 'bg-primary-fixed/50 text-electric-blue', link: '/joki-tugas-mobile-app',
    desc: 'Aplikasi Android & iOS yang smooth untuk tugas akhir, project kuliah, atau aplikasi yang mau kamu rilis.',
    tags: ['Flutter', 'React Native', 'Kotlin', 'Swift'],
  },
  {
    icon: 'desktop_windows', title: 'Aplikasi Desktop', color: 'bg-tertiary-fixed/40 text-tertiary', link: '/joki-aplikasi-desktop',
    desc: 'Program desktop berbasis Java, C++, Python, atau .NET untuk tugas praktikum sampai project skala lab.',
    tags: ['Java', 'C++', 'Python', '.NET'],
  },
  {
    icon: 'database', title: 'Database & API', color: 'bg-tertiary-fixed/40 text-tertiary', link: '/joki-database-api',
    desc: 'Desain skema database yang rapi, optimalisasi query, dan REST API / GraphQL yang aman. Project nggak berantakan pas dikembangkan.',
    tags: ['MySQL', 'PostgreSQL', 'Supabase', 'Node.js'],
  },
  {
    icon: 'analytics', title: 'Data Science & AI', color: 'bg-error-container text-urgency-red', link: '/joki-data-science-ai',
    desc: 'Analisis data, machine learning models, scraping, dan implementasi algoritma AI untuk tugas kuliah atau riset.',
    tags: ['Python', 'Pandas', 'Scikit-learn', 'ML'],
  },
  {
    icon: 'bug_report', title: 'Selamatkan Kode Error', color: 'bg-error-container text-urgency-red', popular: true, link: '/joki-debug-error',
    desc: 'Kode ChatGPT atau codingan sendiri yang error dan bikin pusing? Kami cari akar masalahnya, perbaiki, sampai benar-benar jalan.',
    tags: ['Debug', 'Refactor', 'Fix Error'],
  },

  {
    icon: 'school', title: 'Tugas Kuliah IT', color: 'bg-primary-fixed/50 text-electric-blue', link: '/joki-tugas-kuliah-it',
    desc: 'Materi kuliah seperti struktur data, basis data, pemrograman web, sampai skripsi bagian coding. Dikerjakan sesuai aturan dosen.',
    tags: ['Skripsi', 'Tugas Akhir', 'Praktikum'],
  },
  {
    icon: 'school', title: 'Skripsi & Final Project', color: 'bg-tertiary-fixed/40 text-tertiary', link: '/joki-skripsi-it',
    desc: 'Bantuan teknis skripsi: fix bug, integrasi API & database, sampai persiapan demo dan deploy.',
    tags: ['Skripsi', 'Tugas Akhir', 'Capstone', 'Sidang'],
  },
  {
    icon: 'palette', title: 'Desain UI/UX', color: 'bg-success-green/10 text-success-green', link: '/joki-desain-ui-ux',
    desc: 'Desain tampilan aplikasi dan website yang modern, rapi, dan mobile-friendly. Siap di-slicing ke kode.',
    tags: ['Figma', 'Prototype', 'Responsive'],
  },
]
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Header -->
      <section class="text-center max-w-2xl mx-auto mb-12">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5">
          <span class="material-symbols-outlined text-electric-blue text-[18px]">handyman</span>
          <span class="font-label-sm text-label-sm text-secondary">Layanan Kami</span>
        </div>
        <h1 class="font-headline-lg text-headline-lg md:text-display-hero-mobile font-bold text-on-surface mb-3">Lagi mentok di bagian mana?</h1>
        <p class="text-body-lg font-body-lg text-on-surface-variant">Mulai dari error kecil sampai project kuliah yang bikin begadang. Semua kami bantu bereskan.</p>
      </section>

      <!-- Grid Layanan -->
      <section class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-14">
        <RouterLink v-for="s in services" :key="s.title" :to="s.link || '/request'"
          class="group bg-surface-white border border-border-subtle rounded-2xl p-6 shadow-[0px_4px_20px_rgba(15,23,42,0.04)] hover:shadow-[0px_8px_30px_rgba(15,23,42,0.08)] hover:border-electric-blue transition-all duration-300 flex flex-col h-full relative overflow-hidden">
          <div class="absolute top-0 right-0 w-32 h-32 bg-electric-blue/5 rounded-bl-full -z-10 transition-transform group-hover:scale-110"></div>
          <div class="flex justify-between items-start mb-5">
            <span class="w-12 h-12 rounded-xl flex items-center justify-center" :class="s.color">
              <span class="material-symbols-outlined text-2xl" style="font-variation-settings: 'FILL' 1">{{ s.icon }}</span>
            </span>
            <span v-if="s.popular" class="bg-urgency-red/10 text-urgency-red px-2 py-1 rounded text-[10px] font-bold uppercase tracking-wider">Paling Laku</span>
          </div>
          <h2 class="font-headline-md text-headline-md text-on-surface mb-2">{{ s.title }}</h2>
          <p class="font-body-md text-body-md text-on-surface-variant mb-5 flex-grow">{{ s.desc }}</p>
          <div class="flex flex-wrap gap-2 mt-auto">
            <span v-for="t in s.tags" :key="t" class="bg-surface-container-high text-on-secondary-container px-3 py-1 rounded-full font-label-sm text-label-sm">{{ t }}</span>
          </div>
          <span class="inline-flex items-center gap-1 text-electric-blue font-label-bold text-label-bold mt-4 group-hover:gap-2 transition-all">Lihat Layanan <span class="material-symbols-outlined text-[18px]">arrow_forward</span></span>
        </RouterLink>
      </section>

      <!-- CTA -->
      <section class="bg-electric-blue rounded-2xl p-8 md:p-12 text-center text-white relative overflow-hidden">
        <div class="absolute inset-0 bg-primary opacity-20 -z-10"></div>
        <span class="material-symbols-outlined text-5xl mb-4" style="font-variation-settings: 'FILL' 1">help</span>
        <h2 class="font-headline-lg text-headline-lg font-bold mb-2">Bingung Mulai dari Mana?</h2>
        <p class="text-body-md text-body-md text-on-primary-container opacity-90 max-w-lg mx-auto mb-7">Nggak perlu jago menjelaskan teknis. Ceritakan masalahnya, kami bantu cari solusinya.</p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-white text-electric-blue font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-surface-container-lowest transition-colors shadow-md">Konsultasi Gratis</RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="border-2 border-white text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-white/10 transition-colors">Chat WhatsApp</a>
        </div>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
