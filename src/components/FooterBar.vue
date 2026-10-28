<script setup>
import { RouterLink } from 'vue-router'
</script>

<template>
  <footer class="bg-surface-container-lowest border-t border-border-subtle pb-16 md:pb-0">
    <div class="flex flex-col md:flex-row justify-between items-center py-section-gap-mobile md:py-12 px-gutter max-w-container-max-width mx-auto">
      <RouterLink to="/" class="text-headline-md font-headline-md font-extrabold text-primary mb-4 md:mb-0">
        jokitugasit.my.id
      </RouterLink>
      <nav class="flex flex-wrap justify-center gap-6 mb-6 md:mb-0 font-label-sm text-label-sm text-secondary">
        <RouterLink to="/layanan" class="hover:text-electric-blue underline transition-all opacity-80 hover:opacity-100">Layanan</RouterLink>
        <RouterLink to="/blog" class="hover:text-electric-blue underline transition-all opacity-80 hover:opacity-100">Blog & Tips</RouterLink>
        <RouterLink to="/tanya-jawab" class="hover:text-electric-blue underline transition-all opacity-80 hover:opacity-100">Tanya Jawab</RouterLink>
        <RouterLink to="/testimoni" class="hover:text-electric-blue underline transition-all opacity-80 hover:opacity-100">Testimoni</RouterLink>
        <RouterLink to="/tentang" class="hover:text-electric-blue underline transition-all opacity-80 hover:opacity-100">Tentang</RouterLink>
      </nav>
      <div class="font-label-sm text-label-sm text-secondary opacity-80">
        © 2026 jokitugasit.my.id - Dibuat dengan ❤️ untuk Mahasiswa
      </div>
    </div>
  </footer>
</template>