<script setup>
import { RouterLink } from 'vue-router'
</script>

<template>
  <header
    class="hidden md:flex bg-surface-white dark:bg-inverse-surface shadow-[0px_4px_20px_rgba(15,23,42,0.08)] full-width top-0 sticky z-50"
  >
    <div class="flex justify-between items-center h-16 px-gutter max-w-container-max-width mx-auto w-full">
      <RouterLink to="/" class="flex items-center gap-2">
        <span
          class="material-symbols-outlined text-electric-blue text-2xl"
          style="font-variation-settings: 'FILL' 1"
          >terminal</span
        >
        <span class="text-headline-md font-headline-md font-extrabold text-primary dark:text-primary-fixed tracking-tight">
          JokiTugasIT.id
        </span>
      </RouterLink>
      <nav class="flex items-center gap-8 font-label-bold text-label-bold">
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/layanan">Layanan</RouterLink>
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/cara-kerja">Cara Kerja</RouterLink>
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/tentang">Tentang</RouterLink>
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/track">Cek Status</RouterLink>
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/tanya-jawab">Tanya Jawab</RouterLink>
      </nav>

    </div>
  </header>
</template>