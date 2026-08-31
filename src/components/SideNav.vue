<script setup>
import { RouterLink, useRoute, useRouter } from 'vue-router'
import { useAuthStore } from '../stores/auth'

const route = useRoute()
const router = useRouter()
const auth = useAuthStore()

const navItems = [
  { label: 'Dashboard', icon: 'dashboard', to: '/dashboard' },
  { label: 'Requests', icon: 'list_alt', to: '/requests' },
  { label: 'Earnings', icon: 'payments', to: '/earnings' },
  { label: 'Settings', icon: 'settings', to: '/settings' },
]

const isActive = (to) => route.path.startsWith(to)

async function handleLogout() {
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
      <button class="text-electric-blue" @click="handleLogout" title="Logout">
        <span class="material-symbols-outlined">logout</span>
      </button>
    </header>

    <!-- Desktop sidebar -->
    <aside class="hidden md:flex flex-col h-screen py-4 bg-surface-white shadow-2xl fixed inset-y-0 left-0 w-64 z-[60]">
      <div class="px-6 pb-6 border-b border-border-subtle">
        <h1 class="text-headline-lg font-headline-lg font-extrabold text-electric-blue mb-1">JokiTugasIT.id</h1>
        <p class="font-body-md text-body-md text-secondary">Expert Friend Engineer</p>
        <div class="flex items-center gap-2 mt-2">
          <div class="w-2 h-2 rounded-full bg-success-green pulse-dot"></div>
          <span class="font-label-sm text-label-sm text-secondary">Engineer Available</span>
        </div>
      </div>
      <nav class="flex-1 py-4 px-2 space-y-1 overflow-y-auto">
        <RouterLink
          v-for="item in navItems"
          :key="item.label"
          :to="item.to"
          class="flex items-center gap-3 px-4 py-3 rounded-lg transition-all"
          :class="isActive(item.to) ? 'bg-primary-container text-on-primary-container' : 'text-on-surface-variant hover:bg-surface-container-low'"
        >
          <span class="material-symbols-outlined">{{ item.icon }}</span>
          <span class="font-label-bold text-label-bold">{{ item.label }}</span>
        </RouterLink>
      </nav>
      <div class="px-6 mt-auto space-y-2">
        <div v-if="auth.profile" class="flex items-center gap-3 px-2 pb-2">
          <div class="w-9 h-9 rounded-full bg-primary-container text-on-primary-container flex items-center justify-center font-label-bold">
            {{ (auth.profile.name || 'E').charAt(0).toUpperCase() }}
          </div>
          <div class="min-w-0">
            <p class="text-label-bold font-label-bold truncate">{{ auth.profile.name || 'Engineer' }}</p>
            <p class="text-label-sm text-secondary">{{ auth.profile.email }}</p>
          </div>
        </div>
        <button
          class="w-full bg-electric-blue text-on-primary font-label-bold text-label-bold py-3 rounded-lg shadow-sm hover:scale-95 transition-transform duration-200"
          @click="router.push('/request')"
        >
          Kirim Project
        </button>
        <button
          class="w-full bg-transparent border border-electric-blue text-electric-blue font-label-bold text-label-bold py-2.5 rounded-lg hover:bg-surface-container-low transition-colors"
          @click="handleLogout"
        >
          Logout
        </button>
      </div>
    </aside>

    <!-- Mobile bottom nav -->
    <nav class="md:hidden fixed bottom-0 w-full flex justify-around items-center px-4 py-2 bg-surface-white/90 backdrop-blur-md z-50 shadow-[0_-4px_10px_rgba(0,0,0,0.05)]">
      <RouterLink
        v-for="item in navItems"
        :key="item.label"
        :to="item.to"
        class="flex flex-col items-center justify-center rounded-xl p-2 active:scale-90 duration-150"
        :class="isActive(item.to) ? 'bg-primary-container text-on-primary-container' : 'text-on-secondary-container'"
      >
        <span class="material-symbols-outlined">{{ item.icon }}</span>
        <span class="font-label-sm text-label-sm mt-1">{{ item.label }}</span>
      </RouterLink>
    </nav>

    <main class="flex-1 md:ml-64 p-gutter pt-8 md:pt-12 md:px-section-gap-desktop pb-32 md:pb-12 max-w-container-max-width w-full">
      <slot />
    </main>
  </div>
</template>