<script setup>
import { RouterLink } from 'vue-router'
import { waLink } from '../lib/api'

const WA_NUMBER = '6285166337257'
const waTanya = waLink(WA_NUMBER, 'Halo jokitugasit.my.id, saya ingin bertanya.')

// Semua tautan di bawah sudah ada di router (diverifikasi), bukan karangan.
const kolomLayanan = [
  { label: 'Joki Tugas Kuliah IT', to: '/joki-tugas-kuliah-it' },
  { label: 'Bimbingan Skripsi IT', to: '/joki-skripsi-it' },
  { label: 'Project Web', to: '/joki-project-web' },
  { label: 'Aplikasi Mobile', to: '/joki-tugas-mobile-app' },
  { label: 'Database & API', to: '/joki-database-api' },
  { label: 'Debug Error', to: '/joki-debug-error' },
]

const kolomInformasi = [
  { label: 'Semua Layanan', to: '/layanan' },
  { label: 'Cara Kerja', to: '/cara-kerja' },
  { label: 'Estimasi Harga', to: '/harga' },
  { label: 'Tanya Jawab', to: '/tanya-jawab' },
  { label: 'Portofolio', to: '/portofolio' },
  { label: 'Blog & Tips', to: '/blog' },
  { label: 'Tentang Kami', to: '/tentang' },
]

const kolomAkun = [
  { label: 'Kirim Project', to: '/request' },
  { label: 'Cek Status Order', to: '/track' },
  { label: 'Testimoni', to: '/testimoni' },
  { label: 'Jadi Partner', to: '/partner' },
]

const tahun = new Date().getFullYear()
</script>

<template>
  <footer class="border-t border-border-subtle bg-surface-white pb-20 md:pb-0">
    <div class="mx-auto max-w-container-max-width px-gutter">
      <!-- Bagian atas: brand + peta tautan -->
      <div class="grid gap-10 py-12 md:grid-cols-2 lg:grid-cols-[1.4fr_1fr_1fr_1fr] lg:gap-8">
        <!-- Brand & kontak -->
        <div>
          <RouterLink to="/" class="flex items-center gap-2" aria-label="jokitugasit.my.id — beranda">
            <span
              class="material-symbols-outlined grid h-9 w-9 place-items-center rounded-lg bg-primary text-xl text-on-primary"
              style="font-variation-settings: 'FILL' 1"
              aria-hidden="true"
              >terminal</span
            >
            <span class="text-[17px] font-extrabold tracking-tight text-on-surface">
              jokitugasit<span class="text-primary">.my.id</span>
            </span>
          </RouterLink>

          <p class="mt-4 max-w-xs text-sm leading-relaxed text-secondary">
            Bantuan teknis untuk mahasiswa dan developer awal: pengerjaan tugas,
            debugging, bimbingan, dan review kode — dengan penjelasan yang bisa
            dipertanggungjawabkan.
          </p>

          <a
            :href="waTanya"
            target="_blank"
            rel="noopener noreferrer"
            class="mt-5 inline-flex items-center gap-2 rounded-lg border border-border-subtle px-3.5 py-2 text-sm font-semibold text-on-surface transition-colors hover:border-outline hover:bg-surface-container-low"
          >
            <span class="material-symbols-outlined text-base text-success-green" aria-hidden="true">chat</span>
            Hubungi via WhatsApp
          </a>
        </div>

        <!-- Layanan -->
        <nav aria-label="Layanan">
          <h2 class="text-[11px] font-bold uppercase tracking-widest text-secondary">Layanan</h2>
          <ul class="mt-4 space-y-2.5">
            <li v-for="item in kolomLayanan" :key="item.to">
              <RouterLink
                :to="item.to"
                class="text-sm text-secondary transition-colors hover:text-primary"
              >
                {{ item.label }}
              </RouterLink>
            </li>
          </ul>
        </nav>

        <!-- Informasi -->
        <nav aria-label="Informasi">
          <h2 class="text-[11px] font-bold uppercase tracking-widest text-secondary">Informasi</h2>
          <ul class="mt-4 space-y-2.5">
            <li v-for="item in kolomInformasi" :key="item.to">
              <RouterLink
                :to="item.to"
                class="text-sm text-secondary transition-colors hover:text-primary"
              >
                {{ item.label }}
              </RouterLink>
            </li>
          </ul>
        </nav>

        <!-- Akun -->
        <nav aria-label="Akun dan status">
          <h2 class="text-[11px] font-bold uppercase tracking-widest text-secondary">Akun</h2>
          <ul class="mt-4 space-y-2.5">
            <li v-for="item in kolomAkun" :key="item.to">
              <RouterLink
                :to="item.to"
                class="text-sm text-secondary transition-colors hover:text-primary"
              >
                {{ item.label }}
              </RouterLink>
            </li>
          </ul>
        </nav>
      </div>

      <!-- Bagian bawah: legal -->
      <div
        class="flex flex-col gap-3 border-t border-border-subtle py-6 text-xs text-secondary sm:flex-row sm:items-center sm:justify-between"
      >
        <p>© {{ tahun }} jokitugasit.my.id — Bantuan teknis yang bisa dipertanggungjawabkan.</p>
        <p class="text-secondary">
          Dibangun dengan Vue.js dan Supabase.
        </p>
      </div>
    </div>
  </footer>
</template>
