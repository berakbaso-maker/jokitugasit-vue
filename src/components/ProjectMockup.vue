<script setup>
/**
 * ProjectMockup — ilustrasi "tangkapan layar" abstrak untuk kartu portofolio.
 *
 * SENGAJA bukan screenshot asli: ini mockup dekoratif yang dibuat dari blok
 * UI sederhana, supaya tidak menampilkan data atau wajah palsu. Warnanya
 * diambil dari `gradient` milik proyek agar tiap kategori mudah dikenali.
 *
 * Semua elemen SVG diberi aria-hidden + role="presentation"; teks alternatif
 * disediakan lewat prop `alt` pada pembungkusnya.
 */
const props = defineProps({
  gradient: { type: Array, default: () => ['#2563EB', '#1E3A8A'] },
  icon: { type: String, default: 'widgets' },
  /** 'wide' untuk kartu unggulan, 'card' untuk grid biasa. */
  variant: { type: String, default: 'card' },
})

// id unik supaya gradien antar-instance tidak saling menimpa
const uid = `mk${Math.random().toString(36).slice(2, 9)}`
</script>

<template>
  <div
    class="relative overflow-hidden"
    :class="variant === 'wide' ? 'aspect-[16/9]' : 'aspect-[16/10]'"
    role="img"
    :aria-label="`Ilustrasi antarmuka proyek`"
  >
    <svg
      class="h-full w-full"
      viewBox="0 0 320 200"
      preserveAspectRatio="xMidYMid slice"
      aria-hidden="true"
      role="presentation"
    >
      <defs>
        <linearGradient :id="uid" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" :stop-color="gradient[0]" />
          <stop offset="100%" :stop-color="gradient[1]" />
        </linearGradient>
      </defs>

      <!-- latar gradien -->
      <rect width="320" height="200" :fill="`url(#${uid})`" />

      <!-- lingkaran dekoratif -->
      <circle cx="286" cy="26" r="64" fill="#ffffff" opacity="0.07" />
      <circle cx="34" cy="182" r="52" fill="#ffffff" opacity="0.06" />

      <!-- jendela aplikasi -->
      <g transform="translate(30 34)">
        <rect width="260" height="146" rx="8" fill="#ffffff" opacity="0.96" />

        <!-- title bar -->
        <rect width="260" height="20" rx="8" fill="#F1F5F9" />
        <rect y="12" width="260" height="8" fill="#F1F5F9" />
        <circle cx="12" cy="10" r="2.6" fill="#CBD5E1" />
        <circle cx="21" cy="10" r="2.6" fill="#CBD5E1" />
        <circle cx="30" cy="10" r="2.6" fill="#CBD5E1" />
        <rect x="44" y="7" width="86" height="6" rx="3" fill="#E2E8F0" />

        <!-- sidebar -->
        <rect x="0" y="20" width="52" height="126" fill="#F8FAFC" />
        <rect x="9" y="32" width="34" height="5" rx="2.5" :fill="gradient[0]" opacity="0.85" />
        <rect x="9" y="46" width="26" height="5" rx="2.5" fill="#CBD5E1" />
        <rect x="9" y="58" width="30" height="5" rx="2.5" fill="#CBD5E1" />
        <rect x="9" y="70" width="22" height="5" rx="2.5" fill="#CBD5E1" />
        <rect x="9" y="82" width="28" height="5" rx="2.5" fill="#CBD5E1" />

        <!-- kartu statistik -->
        <g transform="translate(62 30)">
          <rect width="56" height="30" rx="4" fill="#F1F5F9" />
          <rect x="6" y="7" width="20" height="4" rx="2" fill="#CBD5E1" />
          <rect x="6" y="16" width="30" height="7" rx="3.5" :fill="gradient[0]" opacity="0.8" />

          <rect x="64" width="56" height="30" rx="4" fill="#F1F5F9" />
          <rect x="70" y="7" width="20" height="4" rx="2" fill="#CBD5E1" />
          <rect x="70" y="16" width="26" height="7" rx="3.5" fill="#CBD5E1" />

          <rect x="128" width="56" height="30" rx="4" fill="#F1F5F9" />
          <rect x="134" y="7" width="20" height="4" rx="2" fill="#CBD5E1" />
          <rect x="134" y="16" width="22" height="7" rx="3.5" fill="#CBD5E1" />
        </g>

        <!-- grafik batang -->
        <g transform="translate(62 70)">
          <rect width="184" height="52" rx="4" fill="#F8FAFC" />
          <rect x="10" y="34" width="12" height="12" rx="2" :fill="gradient[0]" opacity="0.45" />
          <rect x="28" y="26" width="12" height="20" rx="2" :fill="gradient[0]" opacity="0.55" />
          <rect x="46" y="30" width="12" height="16" rx="2" :fill="gradient[0]" opacity="0.45" />
          <rect x="64" y="18" width="12" height="28" rx="2" :fill="gradient[0]" opacity="0.7" />
          <rect x="82" y="24" width="12" height="22" rx="2" :fill="gradient[0]" opacity="0.55" />
          <rect x="100" y="12" width="12" height="34" rx="2" :fill="gradient[0]" opacity="0.85" />
          <rect x="118" y="20" width="12" height="26" rx="2" :fill="gradient[0]" opacity="0.65" />
          <rect x="136" y="14" width="12" height="32" rx="2" :fill="gradient[0]" opacity="0.75" />
          <rect x="154" y="8" width="12" height="38" rx="2" :fill="gradient[0]" opacity="0.95" />
        </g>

        <!-- baris tabel -->
        <g transform="translate(62 130)">
          <rect width="184" height="4" rx="2" fill="#E2E8F0" />
          <rect y="9" width="150" height="4" rx="2" fill="#E2E8F0" />
        </g>
      </g>
    </svg>

    <!-- ikon kategori -->
    <div
      class="absolute bottom-3 right-3 grid h-9 w-9 place-items-center rounded-lg bg-white/95 shadow-sm backdrop-blur"
    >
      <span class="material-symbols-outlined text-lg text-on-surface" aria-hidden="true">{{
        icon
      }}</span>
    </div>
  </div>
</template>
