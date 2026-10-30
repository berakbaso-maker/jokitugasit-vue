<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { waLink } from '../lib/tautan'

const WA_TEXT = 'Halo jokitugasit.my.id, saya mau tanya cara kerja jasa bantu tugas IT.'

const steps = [
  { num: '01', icon: 'send', title: 'Kirim', desc: 'Isi form 30 detik atau langsung chat WhatsApp. Nggak perlu daftar, nggak perlu login.' },
  { num: '02', icon: 'chat', title: 'Ngobrol', desc: 'Langsung nyambung ke engineer. Ceritain detailnya santai di WhatsApp.' },
  { num: '03', icon: 'search', title: 'Dicek', desc: 'Kami cek tingkat kesulitan dan estimasi waktu pengerjaannya. Dijawab cepat.' },
  { num: '04', icon: 'handshake', title: 'Nego', desc: 'Diskusikan harga yang masuk akal dan sesuai budget mahasiswa. Transparan.' },
  { num: '05', icon: 'verified', title: 'Deal', desc: 'Setelah deal dan DP, kami langsung mulai mengerjakan project-mu.' },
  { num: '06', icon: 'task_alt', title: 'Beres', desc: 'Project selesai, kita review bareng, lalu siap dikumpulkan.' },
]

const guarantees = [
  { icon: 'schedule', title: 'Cepat', desc: 'Deadline hari ini pun bisa dikejar.' },
  { icon: 'verified_user', title: 'Aman & Privat', desc: 'Data project kamu dijaga, nggak disebar.' },
  { icon: 'payments', title: 'Harga Mahasiswa', desc: 'Sebut budget kamu, kami sesuaikan scope-nya. Pas di kantong.' },
  { icon: 'support_agent', title: '24/7 Tanya', desc: 'Bisa chat kapan pun kalau bingung.' },
]
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main id="konten-utama" tabindex="-1" class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <!-- Header -->
      <section class="text-center max-w-2xl mx-auto mb-14">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-2 shadow-sm mb-5">
          <span class="material-symbols-outlined text-electric-blue text-[18px]">route</span>
          <span class="font-label-sm text-label-sm text-secondary">Cara Kerja</span>
        </div>
        <h1 class="font-headline-lg text-headline-lg md:text-display-hero-mobile font-bold text-on-surface mb-3">Alurnya sesimpel ini.</h1>
        <p class="text-body-lg font-body-lg text-on-surface-variant">Nggak perlu ribet dan nggak ada biaya tersembunyi. Semua jelas dari awal sampai selesai.</p>
      </section>

      <!-- Steps -->
      <section class="flex flex-col lg:flex-row gap-6 mb-16 relative">
        <div class="hidden lg:block absolute top-1/2 left-8 right-8 h-1 bg-border-subtle -translate-y-1/2 z-0"></div>
        <div v-for="step in steps" :key="step.num"
          class="flex-1 bg-surface-white rounded-2xl p-6 shadow-sm border border-border-subtle relative z-10 flex flex-col items-center text-center hover:-translate-y-1 transition-transform duration-300">
          <div class="w-12 h-12 bg-primary-fixed rounded-full flex items-center justify-center font-headline-md text-headline-md text-electric-blue mb-4 shadow-inner">{{ step.num }}</div>
          <span class="material-symbols-outlined text-electric-blue mb-2">{{ step.icon }}</span>
          <h2 class="font-label-bold text-label-bold text-on-surface mb-2 text-lg">{{ step.title }}</h2>
          <p class="font-body-md text-body-md text-on-surface-variant text-sm">{{ step.desc }}</p>
        </div>
      </section>

      <!-- Jaminan -->
      <section class="mb-16">
        <h2 class="font-headline-md text-headline-md font-bold text-center mb-8">Kenapa pilih JokiTugasIT?</h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          <div v-for="g in guarantees" :key="g.title" class="bg-surface-white rounded-xl p-5 border border-border-subtle shadow-sm flex flex-col items-center text-center">
            <span class="w-12 h-12 rounded-full bg-primary-fixed/40 text-electric-blue flex items-center justify-center mb-3">
              <span class="material-symbols-outlined">{{ g.icon }}</span>
            </span>
            <h3 class="font-label-bold text-label-bold text-on-surface mb-1">{{ g.title }}</h3>
            <p class="text-sm text-secondary">{{ g.desc }}</p>
          </div>
        </div>
      </section>

      <!-- CTA -->
      <section class="text-center">
        <h2 class="font-headline-lg text-headline-lg font-bold mb-3">Siap mulai?</h2>
        <p class="text-body-md text-body-md text-secondary mb-7">Kirim project-mu sekarang, gratis dicek dulu.</p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <RouterLink to="/request" class="bg-accent-fill text-white font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-accent-fill transition-colors shadow-md">Cek Dulu Gratis</RouterLink>
          <a :href="waLink('6285166337257', WA_TEXT)" target="_blank" rel="noopener" class="bg-surface-white border-2 border-electric-blue text-electric-blue font-label-bold text-label-bold px-7 py-3.5 rounded-xl hover:bg-primary-fixed/20 transition-colors">Chat WhatsApp</a>
        </div>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
