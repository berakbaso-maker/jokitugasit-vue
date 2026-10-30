<script setup>
import { RouterLink, useRoute } from 'vue-router'

const route = useRoute()
const whatsappUrl = 'https://wa.me/6285166337257?text=Halo%20jokitugasit.my.id%2C%20saya%20ingin%20konsultasi%20project.'

const items = [
  { label: 'Beranda', icon: 'home', to: '/', type: 'route' },
  { label: 'Konsultasi', icon: 'add_circle', to: '/request', type: 'route' },
  { label: 'Status', icon: 'track_changes', to: '/track', type: 'route' },
  { label: 'WhatsApp', icon: 'chat', to: whatsappUrl, type: 'external' },
]

const isActive = (item) => {
  if (item.type === 'external') return false
  if (item.to === '/') return route.name === 'landing'
  if (item.to === '/request') return route.name === 'request-submit'
  if (item.to === '/track') return ['request-track', 'request-track-order'].includes(route.name)
  return false
}
</script>

<template>
  <nav aria-label="Navigasi bawah" class="md:hidden fixed bottom-0 w-full flex justify-around items-center px-4 py-2 bg-surface-white/90 dark:bg-inverse-surface/90 backdrop-blur-md z-50 shadow-[0_-4px_10px_rgba(0,0,0,0.05)]">
    <template v-for="item in items" :key="item.label">
      <a v-if="item.type === 'external'" :href="item.to" target="_blank" rel="noopener noreferrer" class="flex flex-col items-center justify-center rounded-xl p-2 w-[72px] h-[56px] text-on-secondary-container active:bg-surface-container-high active:scale-90 duration-150 transition-transform">
        <span class="material-symbols-outlined mb-1" aria-hidden="true">{{ item.icon }}</span>
        <span class="font-label-sm text-label-sm text-[10px]">{{ item.label }}</span>
      </a>
      <RouterLink v-else :to="item.to" class="flex flex-col items-center justify-center rounded-xl p-2 w-[72px] h-[56px] active:scale-90 duration-150 transition-transform" :class="isActive(item) ? 'bg-primary-container text-on-primary-container' : 'text-on-secondary-container active:bg-surface-container-high'">
        <span class="material-symbols-outlined mb-1" aria-hidden="true" :style="{ fontVariationSettings: isActive(item) ? `'FILL' 1` : `'FILL' 0` }">{{ item.icon }}</span>
        <span class="font-label-sm text-label-sm text-[10px]">{{ item.label }}</span>
      </RouterLink>
    </template>
  </nav>
</template>
