<script setup>
import { ref, watch, onMounted, onBeforeUnmount, nextTick } from 'vue'
import { RouterLink, useRoute } from 'vue-router'

const route = useRoute()
const menuTerbuka = ref(false)
const layananTerbuka = ref(false)

const tombolMenu = ref(null)
const wadahLayanan = ref(null)

/**
 * Item navigasi utama.
 *
 * PENTING: tidak ada lagi class responsif berbasis indeks array seperti
 * `{ 'hidden lg:inline-flex': i >= 3 }`. Aturan berbasis indeks rapuh —
 * begitu urutan item berubah, item yang salah ikut tersembunyi, dan di
 * lebar 768–1023px dulu ada item yang tidak bisa dijangkau sama sekali
 * (nav desktop sudah tampil, tapi hamburger & bottom nav sudah hilang).
 *
 * Sekarang: nav desktop tampil mulai `lg`, di bawah `lg` semuanya lewat
 * drawer. Tidak ada item yang bisa "hilang" di breakpoint mana pun.
 */
const tautan = [
  { label: 'Harga', to: '/harga' },
  { label: 'Cara Kerja', to: '/cara-kerja' },
  { label: 'Cek Status', to: '/track' },
  { label: 'Tanya Jawab', to: '/tanya-jawab' },
]

const layanan = [
  { label: 'Bikin Website', to: '/joki-project-web' },
  { label: 'Aplikasi Mobile', to: '/joki-tugas-mobile-app' },
  { label: 'Aplikasi Desktop', to: '/joki-aplikasi-desktop' },
  { label: 'Database & API', to: '/joki-database-api' },
  { label: 'Data Science & AI', to: '/joki-data-science-ai' },
  { label: 'Selamatkan Kode Error', to: '/joki-debug-error' },
  { label: 'Tugas Kuliah IT', to: '/joki-tugas-kuliah-it' },
  { label: 'Skripsi & Final Project', to: '/joki-skripsi-it' },
  { label: 'Desain UI/UX', to: '/joki-desain-ui-ux' },
]

// Drawer mobile: "Beranda" eksplisit ada di sini. Di desktop juga ada
// (link tersendiri di nav, lihat template) -- logo saja tidak cukup jelas
// sebagai satu-satunya jalan pulang.
//
// Catatan: jangan tambahkan Beranda ke array `tautan`, karena array itu
// di-spread ke sini dan akan menghasilkan dua link Beranda.
const tautanMobile = [
  { label: 'Beranda', to: '/' },
  { label: 'Layanan', to: '/layanan' },
  ...tautan,
  { label: 'Testimoni', to: '/testimoni' },
  { label: 'Tentang', to: '/tentang' },
]

const aktif = (to) => {
  if (!to) return false
  const navAktif = route.meta?.navAktif
  if (navAktif && navAktif === to) return true
  if (to === '/') return route.path === '/'
  return route.path === to || route.path.startsWith(to + '/')
}

const tutupSemua = () => {
  menuTerbuka.value = false
  layananTerbuka.value = false
}

const toggleMenu = () => {
  menuTerbuka.value = !menuTerbuka.value
  if (menuTerbuka.value) layananTerbuka.value = false
}

const tutupMenuKembalikanFokus = () => {
  menuTerbuka.value = false
  nextTick(() => tombolMenu.value?.focus())
}

// Kunci scroll body selama drawer terbuka.
watch(menuTerbuka, (buka) => {
  if (typeof document === 'undefined') return
  document.body.style.overflow = buka ? 'hidden' : ''
})

// Menu/dropdown harus tertutup setiap kali rute berubah, kalau tidak
// panel akan menggantung menutupi konten halaman baru.
watch(
  () => route.fullPath,
  () => {
    tutupSemua()
  },
)

const klikDiLuar = (e) => {
  if (!layananTerbuka.value) return
  if (wadahLayanan.value && !wadahLayanan.value.contains(e.target)) {
    layananTerbuka.value = false
  }
}

const tombolEscape = (e) => {
  if (e.key !== 'Escape') return
  if (layananTerbuka.value) {
    layananTerbuka.value = false
    return
  }
  if (menuTerbuka.value) tutupMenuKembalikanFokus()
}

onMounted(() => {
  document.addEventListener('mousedown', klikDiLuar)
  document.addEventListener('keydown', tombolEscape)
})

onBeforeUnmount(() => {
  document.removeEventListener('mousedown', klikDiLuar)
  document.removeEventListener('keydown', tombolEscape)
  if (typeof document !== 'undefined') document.body.style.overflow = ''
})
</script>

<template>
  <header class="sticky top-0 z-50 border-b border-border-subtle bg-surface-white/85 backdrop-blur-md">
    <div class="mx-auto flex h-16 w-full max-w-container-max-width items-center justify-between gap-4 px-gutter">
      <!-- Brand -->
      <RouterLink
        to="/"
        class="flex shrink-0 items-center gap-2 rounded-lg"
        aria-label="jokitugasit.my.id — beranda"
      >
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

      <!-- Navigasi desktop: hanya mulai lg, agar 768–1023px pakai drawer lengkap -->
      <nav class="hidden items-center gap-1 lg:flex" aria-label="Navigasi utama">
        <!-- Beranda: eksplisit di desktop. Di mobile sudah ada di tautanMobile. -->
        <RouterLink
          to="/"
          class="rounded-lg px-3 py-2 text-sm font-semibold transition-colors duration-200"
          :class="
            aktif('/')
              ? 'bg-surface-container text-primary'
              : 'text-secondary hover:bg-surface-container-low hover:text-on-surface'
          "
          :aria-current="aktif('/') ? 'page' : undefined"
        >
          Beranda
        </RouterLink>

        <!-- Dropdown Layanan -->
        <div ref="wadahLayanan" class="relative">
          <button
            type="button"
            class="inline-flex items-center gap-1 rounded-lg px-3 py-2 text-sm font-semibold transition-colors duration-200"
            :class="
              aktif('/layanan')
                ? 'bg-surface-container text-primary'
                : 'text-secondary hover:bg-surface-container-low hover:text-on-surface'
            "
            :aria-expanded="layananTerbuka"
            aria-haspopup="true"
            aria-controls="dropdown-layanan"
            @click="layananTerbuka = !layananTerbuka"
          >
            Layanan
            <span
              class="material-symbols-outlined text-base transition-transform duration-200"
              :class="{ 'rotate-180': layananTerbuka }"
              aria-hidden="true"
              >expand_more</span
            >
          </button>

          <div
            v-show="layananTerbuka"
            id="dropdown-layanan"
            class="absolute left-0 top-full z-50 mt-2 w-64 rounded-xl border border-border-subtle bg-surface-white p-2 shadow-card-hover"
          >
            <RouterLink
              v-for="item in layanan"
              :key="item.to"
              :to="item.to"
              class="block rounded-lg px-3 py-2 text-sm font-semibold text-secondary transition-colors hover:bg-surface-container-low hover:text-on-surface"
              :aria-current="aktif(item.to) ? 'page' : undefined"
            >
              {{ item.label }}
            </RouterLink>
            <RouterLink
              to="/layanan"
              class="mt-1 flex items-center justify-between rounded-lg border-t border-border-subtle px-3 pt-3 pb-2 text-sm font-bold text-primary hover:bg-surface-container-low"
            >
              Lihat semua layanan
              <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_forward</span>
            </RouterLink>
          </div>
        </div>

        <RouterLink
          v-for="item in tautan"
          :key="item.to"
          :to="item.to"
          class="rounded-lg px-3 py-2 text-sm font-semibold transition-colors duration-200"
          :class="
            aktif(item.to)
              ? 'bg-surface-container text-primary'
              : 'text-secondary hover:bg-surface-container-low hover:text-on-surface'
          "
          :aria-current="aktif(item.to) ? 'page' : undefined"
        >
          {{ item.label }}
        </RouterLink>
      </nav>

      <!-- Aksi: CTA selalu tampil mulai md, tautan partner hanya lg -->
      <div class="hidden shrink-0 items-center gap-2 md:flex">
        <RouterLink
          to="/partner"
          class="hidden rounded-lg px-3 py-2 text-sm font-semibold text-secondary transition-colors hover:bg-surface-container-low hover:text-on-surface lg:inline-flex"
          :class="{ 'text-primary': aktif('/partner') }"
        >
          Jadi Partner
        </RouterLink>
        <RouterLink
          to="/request"
          class="inline-flex items-center gap-1.5 rounded-lg bg-primary px-4 py-2 text-sm font-bold text-on-primary shadow-cta transition-[background-color,transform,box-shadow] duration-200 hover:-translate-y-0.5 hover:bg-primary-container"
        >
          Mulai Konsultasi
          <span class="material-symbols-outlined text-base" aria-hidden="true">arrow_forward</span>
        </RouterLink>
      </div>

      <!-- Tombol menu: tampil sampai lg, supaya tablet tidak kehilangan navigasi -->
      <button
        ref="tombolMenu"
        type="button"
        class="grid h-10 w-10 shrink-0 place-items-center rounded-lg border border-border-subtle text-on-surface transition-colors hover:bg-surface-container lg:hidden"
        :aria-expanded="menuTerbuka"
        aria-controls="menu-mobile"
        :aria-label="menuTerbuka ? 'Tutup menu' : 'Buka menu'"
        @click="toggleMenu"
      >
        <span class="material-symbols-outlined" aria-hidden="true">
          {{ menuTerbuka ? 'close' : 'menu' }}
        </span>
      </button>
    </div>

    <!-- Panel menu mobile/tablet -->
    <div
      v-show="menuTerbuka"
      id="menu-mobile"
      class="border-t border-border-subtle bg-surface-white lg:hidden"
    >
      <nav class="mx-auto max-w-container-max-width px-gutter py-4" aria-label="Navigasi mobile">
        <ul class="space-y-1">
          <li v-for="item in tautanMobile" :key="item.to">
            <RouterLink
              :to="item.to"
              class="flex items-center justify-between rounded-lg px-3 py-3 text-sm font-semibold transition-colors"
              :class="
                aktif(item.to)
                  ? 'bg-surface-container text-primary'
                  : 'text-on-surface hover:bg-surface-container-low'
              "
              :aria-current="aktif(item.to) ? 'page' : undefined"
            >
              {{ item.label }}
              <span class="material-symbols-outlined text-base text-secondary" aria-hidden="true"
                >chevron_right</span
              >
            </RouterLink>
          </li>
        </ul>

        <div class="mt-4 flex flex-col gap-2 border-t border-border-subtle pt-4">
          <RouterLink
            to="/request"
            class="inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-4 py-3 text-sm font-bold text-on-primary"
          >
            <span class="material-symbols-outlined text-base" aria-hidden="true">rocket_launch</span>
            Mulai Konsultasi
          </RouterLink>
          <RouterLink
            to="/partner"
            class="inline-flex items-center justify-center gap-2 rounded-lg border border-border-subtle px-4 py-3 text-sm font-bold text-on-surface"
          >
            <span class="material-symbols-outlined text-base" aria-hidden="true">group_add</span>
            Jadi Partner
          </RouterLink>
        </div>
      </nav>
    </div>
  </header>
</template>
