<script setup>
import { computed } from 'vue'
import { useRoute, RouterLink } from 'vue-router'
import TopAppBar from '../components/TopAppBar.vue'
import BottomNavBar from '../components/BottomNavBar.vue'
import FooterBar from '../components/FooterBar.vue'
import { getPost, posts } from '../data/posts'
import { waLink } from '../lib/tautan'

const route = useRoute()
const post = computed(() => getPost(route.params.slug))
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md antialiased flex flex-col">
    <TopAppBar />
    <main id="konten-utama" tabindex="-1" class="flex-1 w-full max-w-container-max-width mx-auto px-gutter py-12 md:py-20">
      <template v-if="post">
        <article class="max-w-3xl mx-auto">
          <div class="flex items-center gap-2 text-sm text-secondary mb-4">
            <RouterLink to="/blog" class="hover:text-electric-blue inline-flex items-center gap-1">
              <span class="material-symbols-outlined text-[18px]">arrow_back</span> Blog
            </RouterLink>
            <span>•</span>
            <span>{{ post.date }}</span>
            <span>•</span>
            <span>{{ post.readTime }} menit baca</span>
          </div>
          <h1 class="font-display-hero-mobile md:font-headline-lg text-display-hero-mobile md:text-headline-lg font-bold text-on-surface mb-6">{{ post.title }}</h1>

          <div class="flex flex-wrap gap-2 mb-8">
            <span v-for="k in post.keywords" :key="k" class="text-xs bg-surface-bright border border-border-subtle px-2.5 py-1 rounded-full text-secondary">{{ k }}</span>
          </div>

          <div class="space-y-8">
            <section v-for="(sec, i) in post.sections" :key="i">
              <h2 class="font-headline-md text-headline-md font-bold text-on-surface mb-3">{{ sec.h }}</h2>
              <p v-for="(par, j) in sec.p" :key="j" class="text-on-surface-variant leading-7 mb-3">{{ par }}</p>
            </section>
          </div>

          <div class="bg-accent-fill rounded-2xl p-7 md:p-9 text-center text-white mt-12">
            <h2 class="font-headline-lg text-headline-lg font-bold mb-3">Masih Mentok? Ceritain Aja</h2>
            <p class="text-body-md text-body-md opacity-90 max-w-md mx-auto mb-6">Konsultasi gratis sama engineer. Kita cek dulu, bahas solusinya, baru kamu putuskan.</p>
            <div class="flex flex-col sm:flex-row gap-3 justify-center">
              <RouterLink to="/request" class="bg-white text-accent-fill font-label-bold text-label-bold px-6 py-3 rounded-xl shadow-md">Cek Project Gratis</RouterLink>
              <a :href="waLink('6285166337257', 'Halo, saya baca artikel blog dan mau konsultasi tugas IT.')" target="_blank" rel="noopener" class="border-2 border-white text-white font-label-bold text-label-bold px-6 py-3 rounded-xl hover:bg-white/10">Chat WhatsApp</a>
            </div>
          </div>
        </article>
      </template>
      <div v-else class="text-center py-16">
        <h1 class="font-headline-lg text-headline-lg font-bold mb-3">Artikel nggak ditemukan</h1>
        <RouterLink to="/blog" class="text-electric-blue font-label-bold">← Kembali ke Blog</RouterLink>
      </div>
    </main>
    <FooterBar />
    <BottomNavBar />
  </div>
</template>
