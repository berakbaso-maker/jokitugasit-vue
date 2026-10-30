<script setup>
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import SideNav from '../components/SideNav.vue'
import { useAuthStore } from '../stores/auth'

const auth = useAuthStore()
const router = useRouter()

const initial = computed(() => auth.profile?.full_name?.charAt(0) || auth.session?.user?.email?.charAt(0) || 'E')
const fullName = computed(() => auth.profile?.full_name || 'Engineer')
const email = computed(() => auth.profile?.email || auth.session?.user?.email || '-')
const whatsapp = computed(() => auth.profile?.whatsapp || 'Belum diatur')
</script>

<template>
  <SideNav>
    <!-- Header -->
    <div class="mb-8">
      <p class="text-label-sm text-electric-blue uppercase tracking-wider mb-2 font-label-sm">Akun</p>
      <h1 class="text-headline-lg font-headline-lg font-bold text-on-surface">Profil & Pengaturan</h1>
      <p class="text-secondary mt-1 font-body-md">Kelola informasi engineer dan preferensi akun.</p>
    </div>

    <!-- Profile Card (full width) -->
    <section class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgb(var(--shadow-color) / 0.08)] p-6 md:p-8 mb-6 w-full">
      <div class="flex flex-col sm:flex-row items-start sm:items-center gap-5 border-b border-border-subtle pb-6">
        <div class="w-16 h-16 rounded-full bg-primary-container text-white flex items-center justify-center text-2xl font-bold shrink-0">{{ initial }}</div>
        <div class="min-w-0">
          <h2 class="text-headline-md font-headline-md font-bold text-on-surface">{{ fullName }}</h2>
          <p class="text-secondary font-body-md">Akun Engineer</p>
        </div>
        <span class="sm:ml-auto inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full bg-success-green/10 text-success-green font-label-sm text-label-sm">
          <span class="w-1.5 h-1.5 rounded-full bg-success-green"></span>
          Aktif
        </span>
      </div>

      <dl class="mt-6 grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-surface-container-low rounded-xl p-4">
          <dt class="text-label-sm text-label-sm text-secondary mb-1.5 flex items-center gap-1.5">
            <span class="material-symbols-outlined text-[16px]">badge</span>
            Nama lengkap
          </dt>
          <dd class="font-semibold text-on-surface">{{ fullName }}</dd>
        </div>
        <div class="bg-surface-container-low rounded-xl p-4">
          <dt class="text-label-sm text-label-sm text-secondary mb-1.5 flex items-center gap-1.5">
            <span class="material-symbols-outlined text-[16px]">mail</span>
            Email
          </dt>
          <dd class="font-semibold text-on-surface break-all">{{ email }}</dd>
        </div>
        <div class="bg-surface-container-low rounded-xl p-4">
          <dt class="text-label-sm text-label-sm text-secondary mb-1.5 flex items-center gap-1.5">
            <span class="material-symbols-outlined text-[16px]">chat</span>
            WhatsApp
          </dt>
          <dd class="font-semibold text-on-surface">{{ whatsapp }}</dd>
        </div>
      </dl>
    </section>

    <!-- Quick Actions (full width) -->
    <section class="bg-surface-white rounded-xl shadow-[0px_4px_20px_rgb(var(--shadow-color) / 0.08)] p-6 md:p-8 w-full">
      <h2 class="text-body-lg font-body-lg font-bold text-on-surface mb-1">Aksi Cepat</h2>
      <p class="text-secondary text-sm mb-5">Akses cepat ke area kerja kamu.</p>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        <button
          @click="router.push('/requests')"
          class="group flex items-center gap-3 p-4 rounded-xl border border-border-subtle bg-surface-container-lowest hover:border-electric-blue hover:shadow-md transition-all text-left"
        >
          <span class="w-11 h-11 rounded-lg bg-primary-fixed/40 text-electric-blue flex items-center justify-center shrink-0 group-hover:bg-primary-fixed/60 transition-colors">
            <span class="material-symbols-outlined">list_alt</span>
          </span>
          <span class="min-w-0">
            <span class="block font-label-bold text-label-bold text-on-surface">Lihat Requests</span>
            <span class="block text-label-sm text-label-sm text-secondary">Kelola semua request project</span>
          </span>
          <span class="material-symbols-outlined ml-auto text-secondary group-hover:text-electric-blue transition-colors">arrow_forward</span>
        </button>
        <button
          @click="router.push('/earnings')"
          class="group flex items-center gap-3 p-4 rounded-xl border border-border-subtle bg-surface-container-lowest hover:border-electric-blue hover:shadow-md transition-all text-left"
        >
          <span class="w-11 h-11 rounded-lg bg-primary-fixed/40 text-electric-blue flex items-center justify-center shrink-0 group-hover:bg-primary-fixed/60 transition-colors">
            <span class="material-symbols-outlined">payments</span>
          </span>
          <span class="min-w-0">
            <span class="block font-label-bold text-label-bold text-on-surface">Lihat Earnings</span>
            <span class="block text-label-sm text-label-sm text-secondary">Pantau pendapatan project</span>
          </span>
          <span class="material-symbols-outlined ml-auto text-secondary group-hover:text-electric-blue transition-colors">arrow_forward</span>
        </button>
        <button
          @click="router.push('/dashboard')"
          class="group flex items-center gap-3 p-4 rounded-xl border border-border-subtle bg-surface-container-lowest hover:border-electric-blue hover:shadow-md transition-all text-left"
        >
          <span class="w-11 h-11 rounded-lg bg-primary-fixed/40 text-electric-blue flex items-center justify-center shrink-0 group-hover:bg-primary-fixed/60 transition-colors">
            <span class="material-symbols-outlined">dashboard</span>
          </span>
          <span class="min-w-0">
            <span class="block font-label-bold text-label-bold text-on-surface">Dashboard</span>
            <span class="block text-label-sm text-label-sm text-secondary">Lihat antrian request hari ini</span>
          </span>
          <span class="material-symbols-outlined ml-auto text-secondary group-hover:text-electric-blue transition-colors">arrow_forward</span>
        </button>
      </div>
    </section>
  </SideNav>
</template>
