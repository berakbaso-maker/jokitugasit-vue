<script setup>
import { RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { posts } from '../data/posts'
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main id="konten-utama" tabindex="-1" class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <section class="text-center max-w-2xl mx-auto mb-12">
        <div class="inline-flex items-center gap-2 bg-surface-white border border-border-subtle rounded-full px-4 py-1.5 shadow-sm mb-4">
          <span class="material-symbols-outlined text-electric-blue text-[18px]">article</span>
          <span class="font-label-sm text-label-sm text-secondary">Blog & Tips</span>
        </div>
        <h1 class="font-display-hero-mobile md:font-display-hero text-display-hero-mobile md:text-display-hero font-bold text-on-surface mb-4">Tips Ngoding & Bantuan Tugas IT</h1>
        <p class="font-body-lg text-body-lg text-on-surface-variant max-w-xl mx-auto">Belajar dari pengalaman: error yang sering terjadi, cara debugging, dan tips pilih bantuan tugas yang aman.</p>
      </section>

      <section class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <RouterLink v-for="p in posts" :key="p.slug" :to="`/blog/${p.slug}`"
          class="group bg-surface-white rounded-2xl p-6 border border-border-subtle shadow-sm hover:shadow-md hover:border-electric-blue transition-all flex flex-col">
          <div class="flex items-center gap-2 text-xs text-secondary mb-3">
            <span class="bg-primary-fixed/40 text-electric-blue px-2.5 py-1 rounded-full font-label-sm text-label-sm">{{ p.readTime }} menit baca</span>
            <span>{{ p.date }}</span>
          </div>
          <h2 class="font-headline-md text-headline-md font-bold text-on-surface mb-2 group-hover:text-electric-blue transition-colors">{{ p.title }}</h2>
          <p class="text-sm text-on-surface-variant leading-6 mb-4 flex-grow">{{ p.excerpt }}</p>
          <div class="flex flex-wrap gap-2 mb-4">
            <span v-for="k in p.keywords" :key="k" class="text-[11px] bg-surface-bright border border-border-subtle px-2 py-0.5 rounded-full text-secondary">{{ k }}</span>
          </div>
          <span class="inline-flex items-center gap-1 text-electric-blue font-label-bold text-label-bold">
            Baca Artikel
            <span class="material-symbols-outlined text-[18px] transition-transform group-hover:translate-x-1">arrow_forward</span>
          </span>
        </RouterLink>
      </section>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
