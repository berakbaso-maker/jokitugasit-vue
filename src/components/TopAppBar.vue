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
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/#services">Services</RouterLink>
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/#how-it-works">How it Works</RouterLink>
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/#about">About</RouterLink>
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/track">Cek Status</RouterLink>
        <RouterLink class="text-secondary hover:text-electric-blue transition-colors duration-200" to="/#how-it-works">FAQ</RouterLink>
      </nav>
      <RouterLink
        to="/login"
        class="bg-electric-blue text-surface-white font-label-bold text-label-bold px-6 py-2.5 rounded-lg hover:bg-primary transition-all duration-200 active:scale-95 shadow-md"
      >
        Engineer Login
      </RouterLink>
    </div>
  </header>
</template>