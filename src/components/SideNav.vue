<script setup>
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const navItems = [
  { label: 'Dasbor', icon: 'dashboard', to: '/dashboard' },
  { label: 'Permintaan', icon: 'list_alt', to: '/requests' },
  { label: 'Pendapatan', icon: 'payments', to: '/earnings' },
  { label: 'Pengaturan', icon: 'settings', to: '/settings' },
]

const isActive = (to) => route.path.startsWith(to)

const profileInitial = () => {
  const name = auth.profile?.full_name || auth.profile?.name || ''
  return name.charAt(0).toUpperCase() || 'E'
}
const profileName = () => auth.profile?.full_name || auth.profile?.name || 'Engineer'

async function handleKeluar() {
  await auth.logout()
  router.push('/')
}
</script>

<template>
  <div class="min-h-screen bg-background text-on-surface font-body-md flex flex-col md:flex-row">
    <!-- Mobile top bar -->
    <header class="md:hidden bg-surface-white shadow-sm z-50 flex justify-between items-center h-16 px-gutter">
      <RouterLink to="/dashboard" class="text-headline-md font-headline-md font-extrabold text-primary">
        JokiTugasIT.id
      </RouterLink>
      <button class="text-electric-blue" @click="handleKeluar" title="Keluar">
        <span class="material-symbols-outlined">logout</span>
      </button>
    </header>

    <!-- Desktop sidebar -->
    <aside class="hidden md:flex flex-col h-screen py-4 bg-surface-white shadow-2xl fixed inset-y-0 left-0 w-64 z-[60]">
      <div class="px-6 pb-5 border-b border-border-subtle">
        <h1 class="text-headline-md font-headline-md font-extrabold text-electric-blue mb-1">JokiTugasIT.id</h1>
        <p class="font-label-sm text-label-sm text-secondary">Teman Ngoding Engineer</p>
        <div class="flex items-center gap-2 mt-3">
          <div class="w-2 h-2 rounded-full bg-success-green pulse-dot"></div>
          <span class="font-label-sm text-label-sm text-secondary">Engineer Siap Bantu</span>
        </div>
      </div>
      <nav class="flex-1 py-4 px-3 space-y-1 overflow-y-auto">
        <RouterLink
          v-for="item in navItems"
          :key="item.label"
          :to="item.to"
          class="flex items-center gap-3 px-3 py-2.5 rounded-lg transition-all"
          :class="isActive(item.to) ? 'bg-primary-container text-on-primary-container' : 'text-on-surface-variant hover:bg-surface-container-low'"
        >
          <span class="material-symbols-outlined text-[22px]">{{ item.icon }}</span>
          <span class="font-label-bold text-label-bold">{{ item.label }}</span>
        </RouterLink>
      </nav>
      <div class="px-4 pb-2 mt-auto space-y-2 border-t border-border-subtle pt-4">
        <div v-if="auth.profile" class="flex items-center gap-3 px-1 pb-2">
          <div class="w-10 h-10 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center font-label-bold shrink-0">
            {{ profileInitial() }}
          </div>
          <div class="min-w-0">
            <p class="text-label-bold font-label-bold truncate">{{ profileName() }}</p>
            <p class="text-label-sm text-secondary truncate">{{ auth.profile.email || 'Engineer' }}</p>
          </div>
        </div>
        <button
          class="w-full bg-electric-blue text-on-primary font-label-bold text-label-bold py-3 rounded-lg shadow-sm hover:bg-primary transition-colors"
          @click="router.push('/request')"
        >
          Kirim Project
        </button>
        <button
          class="w-full bg-transparent border border-electric-blue text-electric-blue font-label-bold text-label-bold py-3 rounded-lg hover:bg-surface-container-low transition-colors"
          @click="handleKeluar"
        >
          Keluar
        </button>
      </div>
    </aside>

    <!-- Mobile bottom nav -->
    <nav class="md:hidden fixed bottom-0 w-full flex justify-around items-center px-2 py-2 bg-surface-white/90 backdrop-blur-md z-50 shadow-[0_-4px_10px_rgba(0,0,0,0.05)]">
      <RouterLink
        v-for="item in navItems"
        :key="item.label"
        :to="item.to"
        class="flex flex-col items-center justify-center rounded-xl p-2 w-[70px] h-[56px] active:scale-90 duration-150"
        :class="isActive(item.to) ? 'bg-primary-container text-on-primary-container' : 'text-on-secondary-container'"
      >
        <span class="material-symbols-outlined text-[22px]" :style="{ fontVariationSettings: isActive(item.to) ? `'FILL' 1` : `'FILL' 0` }">{{ item.icon }}</span>
        <span class="font-label-sm text-label-sm text-[10px] mt-0.5">{{ item.label }}</span>
      </RouterLink>
    </nav>

    <main class="flex-1 md:ml-64 px-4 sm:px-6 md:px-8 pt-6 md:pt-10 pb-32 md:pb-10 w-full min-w-0">
      <slot />
    </main>
  </div>
</template>
